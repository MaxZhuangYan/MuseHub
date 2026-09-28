import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';
import 'download_models.dart';
import 'id3_writer.dart';
import 'music_api.dart';

/// Stores downloaded songs.
///
/// Two locations, deliberately separate:
/// - the *index* (one `<songId>.json` per song) always lives in app-private
///   storage, so a folder the user picks never fills up with JSON files;
/// - the *audio* goes to the user's chosen folder (or the default), named
///   "Title - Artist.mp3" and tagged, so it's recognisable anywhere.
class DownloadService {
  DownloadService({
    MusicApi? api,
    http.Client? client,
  })  : _api = api,
        _client = client ?? http.Client();

  final MusicApi? _api;
  final http.Client _client;

  // Anything smaller than this is not a real song — it's an error page saved
  // as ".mp3", a truncated/interrupted download, or a preview-length clip.
  // The whole "卡顿主要来自坏缓存被当作正常缓存播放" problem is exactly this:
  // a tiny corrupt file living next to good ones and being preferred for
  // playback. We refuse to save such files, refuse to play them, and sweep
  // them out.
  static const _minValidAudioBytes = 100 * 1024;

  // Same headers playback sends (PlayerController._audioStreamHeaders).
  // Netease's CDN enforces Referer-based hotlink protection on some edges;
  // measured against both a free track and a VIP-unlocked one these
  // particular URLs served fine without them, so this is defensive
  // consistency with the playback path rather than a fix for a known
  // failure — downloads should not be the one request type that omits them.
  static const _downloadHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Referer': 'https://music.163.com/',
  };

  // In-progress writes carry this marker. It keeps the real audio extension
  // after it on purpose: Android 11+ only lets an app create files in the
  // shared Music folder when the extension is an audio type, so a plain
  // ".tmp" suffix would be refused there. Being this specific also means
  // cleanup can remove our own leftovers from a user-chosen folder without
  // ever touching the user's files.
  static const _partMarker = '.musehub-part';

  static const _systemChannel = MethodChannel('musehub/system');

  String? _customDirectory;

  /// The folder the user chose for audio, or null for the default.
  String? get customDirectory => _customDirectory;

  // ── Choosing where audio goes ─────────────────────────────────────────

  /// Whether this platform offers a choice of download folder at all.
  bool get canChooseDownloadDirectory => Platform.isMacOS || Platform.isAndroid;

  /// Re-establishes the saved folder on launch. On macOS the app sandbox
  /// only lets us write to a user-picked folder through a security-scoped
  /// bookmark, which has to be resolved again every launch; if that fails
  /// (folder deleted, drive unplugged) we fall back to the default rather
  /// than failing every download.
  Future<String?> restoreCustomDirectory(String? savedPath) async {
    _customDirectory = null;
    if (savedPath == null || savedPath.isEmpty) return null;
    try {
      if (Platform.isMacOS) {
        final path = await _systemChannel.invokeMethod<String>(
          'restoreDirectory',
        );
        if (path == null || path.isEmpty) return null;
        _customDirectory = path;
        return path;
      }
      if (Platform.isAndroid) {
        _customDirectory = savedPath;
        return savedPath;
      }
    } on Object {
      // Fall back to the default folder.
    }
    return null;
  }

  /// macOS: shows the system folder picker. Returns the chosen path, or
  /// null if the user cancelled.
  Future<String?> pickCustomDirectory() async {
    if (!Platform.isMacOS) return null;
    final path = await _systemChannel.invokeMethod<String>('pickDirectory');
    if (path == null || path.isEmpty) return null;
    _customDirectory = path;
    return path;
  }

  /// Android: switches to the shared Music/MuseHub folder, which other
  /// music apps and file managers can see. Returns null if the storage
  /// permission it needs (Android 10 and below) was refused.
  Future<String?> useSharedMusicDirectory() async {
    if (!Platform.isAndroid) return null;
    final granted =
        await _systemChannel.invokeMethod<bool>('ensureSharedStorageWrite');
    if (granted != true) return null;
    final path =
        await _systemChannel.invokeMethod<String>('sharedMusicDirectory');
    if (path == null || path.isEmpty) return null;
    await Directory(path).create(recursive: true);
    _customDirectory = path;
    return path;
  }

  Future<void> useDefaultDirectory() async {
    _customDirectory = null;
    if (Platform.isMacOS) {
      try {
        await _systemChannel.invokeMethod<bool>('clearDirectory');
      } on Object {
        // Nothing to release.
      }
    }
  }

  // ── Listing / lookup ──────────────────────────────────────────────────

  Future<List<DownloadedSong>> listDownloads() async {
    final results = <DownloadedSong>[];
    final seen = <int>{};
    for (final entry in await _indexEntries()) {
      final item = entry.item;
      if (item.song.id == 0 || seen.contains(item.song.id)) continue;
      try {
        final audioFile = File(item.audioPath);
        if (!await audioFile.exists()) continue;
        if (await audioFile.length() < _minValidAudioBytes) {
          // Corrupt/truncated — drop it from the list and clean it up.
          await _deleteQuietly(audioFile);
          await _deleteQuietly(entry.file);
          continue;
        }
        seen.add(item.song.id);
        results.add(item);
      } on Object {
        // Skip an entry we can't read.
      }
    }
    results.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return results;
  }

  Future<String?> localPathForSong(int songId) async {
    for (final dir in await _indexDirs()) {
      try {
        final metadata = File('${dir.path}/$songId.json');
        if (!await metadata.exists()) continue;
        final decoded = jsonDecode(await metadata.readAsString());
        if (decoded is! Map<String, dynamic>) continue;
        final item = DownloadedSong.fromJson(decoded);
        final audioFile = File(item.audioPath);
        if (!await audioFile.exists()) continue;
        // Guard against playing a corrupt/truncated cached file: if it's
        // implausibly small, delete it and its metadata and keep looking so
        // the player falls through to streaming instead of hitting the bad
        // file every time.
        if (await audioFile.length() < _minValidAudioBytes) {
          await _deleteQuietly(audioFile);
          await _deleteQuietly(metadata);
          continue;
        }
        return item.audioPath;
      } on Object {
        // Try the next directory.
      }
    }
    return null;
  }

  // ── Download / delete ─────────────────────────────────────────────────

  Future<DownloadedSong> downloadSong(Song song) async {
    final api = _api;
    if (api == null) {
      throw const MusicApiException('Download service is not configured.');
    }
    final hydrated = await _hydrateSong(song, api);
    final url = await api.songUrl(hydrated);
    if (url == null || url.isEmpty) {
      throw const MusicApiException('No playable URL returned for this song.');
    }

    final response = await _client
        .get(Uri.parse(url), headers: _downloadHeaders)
        .timeout(const Duration(seconds: 60));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicApiException('Download failed (${response.statusCode}).');
    }
    if (response.bodyBytes.length < _minValidAudioBytes) {
      // Don't persist an error page / truncated clip as if it were the song.
      throw const MusicApiException(
        'Downloaded audio looks incomplete or invalid.',
      );
    }

    final ext = _extensionForUrl(url);
    final bytes = ext == '.mp3'
        ? await _tagged(response.bodyBytes, hydrated)
        : response.bodyBytes;
    final dir = await _audioDir();
    await dir.create(recursive: true);
    final target = await _uniqueTarget(dir, hydrated, ext);
    await _writeAtomically(target, bytes);
    await _announceToMediaLibrary(target.path);

    final item = DownloadedSong(
      song: hydrated,
      audioPath: target.path,
      downloadedAt: DateTime.now(),
      bytes: bytes.length,
    );
    await _writeIndex(item);
    return item;
  }

  Future<void> deleteDownload(int songId) async {
    for (final dir in await _indexDirs()) {
      final metadata = File('${dir.path}/$songId.json');
      if (!await metadata.exists()) continue;
      try {
        final decoded = jsonDecode(await metadata.readAsString());
        if (decoded is Map<String, dynamic>) {
          final item = DownloadedSong.fromJson(decoded);
          await _deleteQuietly(File(item.audioPath));
        }
      } on Object {
        // Continue and delete metadata below.
      }
      await _deleteQuietly(metadata);
    }
  }

  // ── Maintenance ───────────────────────────────────────────────────────

  /// Sweeps out corrupt/too-small audio, interrupted-download residue and
  /// orphaned index entries. Returns how many bad files were removed.
  ///
  /// Loose files are only ever deleted from folders MuseHub owns. In a
  /// user-chosen folder the only thing touched is our own `.musehub-part`
  /// leftovers — never a file we didn't write.
  Future<int> cleanUpCache() async {
    var removed = 0;

    for (final entry in await _indexEntries(includeUnreadable: true)) {
      try {
        final item = entry.item;
        final audioFile = File(item.audioPath);
        final gone = !await audioFile.exists();
        if (item.song.id == 0 ||
            gone ||
            await audioFile.length() < _minValidAudioBytes) {
          if (!gone) await _deleteQuietly(audioFile);
          await _deleteQuietly(entry.file);
          removed++;
        }
      } on Object {
        await _deleteQuietly(entry.file);
        removed++;
      }
    }

    final owned = await _ownedDirs();
    final audioDir = await _audioDir();
    for (final dir in {...owned, audioDir}) {
      final isOwned = owned.any((d) => d.path == dir.path);
      try {
        if (!await dir.exists()) continue;
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final path = entity.path;
          try {
            if (path.contains('$_partMarker.')) {
              await _deleteQuietly(entity);
              removed++;
              continue;
            }
            if (!isOwned) continue;
            if (path.endsWith('.tmp') || path.endsWith('.download')) {
              await _deleteQuietly(entity);
              removed++;
              continue;
            }
            if (_isAudioPath(path) &&
                await entity.length() < _minValidAudioBytes) {
              await _deleteQuietly(entity);
              removed++;
            }
          } on Object {
            // One bad file must not abort the sweep.
          }
        }
      } on Object {
        // Best-effort cleanup.
      }
    }
    return removed;
  }

  /// Brings downloads made by older versions up to date: moves their index
  /// entry into the private index folder, renames the audio from a bare
  /// song id ("1357374736.mp3") to "Title - Artist.mp3" in the current
  /// download folder, and writes tags into MP3s that don't carry any.
  /// Safe to run on every launch — once migrated there is nothing to do.
  Future<int> migrateLegacyDownloads() async {
    var migrated = 0;
    final index = await _indexDir();
    final audioDir = await _audioDir();
    for (final entry in await _indexEntries()) {
      final inIndex = entry.file.parent.path == index.path;
      final audio = File(entry.item.audioPath);
      final idName = '${entry.item.song.id}';
      // A song with no usable title falls back to its id as the file name;
      // treat that as already named, or it would be rewritten every launch.
      final named = _stem(audio.path) != idName ||
          _readableName(entry.item.song) == idName;
      if (inIndex && named) continue;
      try {
        if (!await audio.exists()) continue;
        final moved = await _relocate(
          entry.item,
          audioDir,
          retag: !named,
        );
        await _writeIndex(moved);
        if (!inIndex) await _deleteQuietly(entry.file);
        migrated++;
      } on Object {
        // Leave this one as it is; it still plays from its old location.
      }
    }
    return migrated;
  }

  /// Moves every downloaded song into the current download folder, e.g.
  /// after the user picks a new one. Returns how many were moved.
  Future<int> moveDownloadsToCurrentDirectory() async {
    var moved = 0;
    final audioDir = await _audioDir();
    await audioDir.create(recursive: true);
    for (final item in await listDownloads()) {
      if (File(item.audioPath).parent.path == audioDir.path) continue;
      try {
        final relocated = await _relocate(item, audioDir, retag: false);
        await _writeIndex(relocated);
        moved++;
      } on Object {
        // Keep the old copy; it is still indexed and playable.
      }
    }
    return moved;
  }

  // ── Folder access ─────────────────────────────────────────────────────

  /// Absolute path of the folder audio is written to, for showing the user
  /// where their files are.
  Future<String> downloadDirectoryPath() async {
    final dir = await _audioDir();
    return dir.path;
  }

  /// Whether this platform can open the download folder in a file manager.
  /// Android/iOS have no reliable way to do that, so the UI shows the path
  /// instead of offering a button that always fails.
  bool get canOpenDownloadDirectory =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Future<void> openDownloadDirectory() async {
    final dir = await _audioDir();
    await dir.create(recursive: true);
    if (Platform.isMacOS) {
      // The App Sandbox denies spawning /usr/bin/open, so Process.run does
      // nothing here — go through NSWorkspace on the native side instead.
      final opened = await _systemChannel.invokeMethod<bool>(
        'revealPath',
        {'path': dir.path},
      );
      if (opened != true) {
        throw const MusicApiException(
          'Opening the download folder is not available on this platform.',
        );
      }
      return;
    }
    if (Platform.isWindows) {
      await Process.run('explorer', [dir.path]);
      return;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', [dir.path]);
      return;
    }
    throw const MusicApiException(
      'Opening the download folder is not available on this platform.',
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────

  Future<Song> _hydrateSong(Song song, MusicApi api) async {
    if (song.coverUrl.isNotEmpty && song.artists.isNotEmpty) return song;
    try {
      final details = await api.songDetails([song.id]);
      if (details.isEmpty) return song;
      return song.mergeDetails(details.first);
    } on Object {
      return song;
    }
  }

  Future<Uint8List> _tagged(Uint8List audio, Song song) async {
    final artists = song.artists
        .map((artist) => artist.name.trim())
        .where((name) => name.isNotEmpty)
        .join('/');
    return Id3Writer.retag(
      audio,
      title: song.name,
      artist: artists,
      album: song.album,
      cover: await _fetchCover(song.coverUrl),
    );
  }

  /// Best-effort cover download for the ID3 tag. A missing cover never
  /// fails a download — the song is still named and tagged without it.
  Future<Uint8List?> _fetchCover(String coverUrl) async {
    if (coverUrl.isEmpty) return null;
    try {
      var url = coverUrl;
      // Netease serves the original upload (often several MB) unless asked
      // for a size; 500px is plenty for an embedded cover.
      if (url.contains('music.126.net') && !url.contains('?')) {
        url = '$url?param=500y500';
      }
      final response = await _client
          .get(Uri.parse(url), headers: _downloadHeaders)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      if (bytes.isEmpty || bytes.length > 3 * 1024 * 1024) return null;
      return bytes;
    } on Object {
      return null;
    }
  }

  /// Moves (and optionally retags) a song's audio into [targetDir] under
  /// its readable name. Returns the entry pointing at the new file.
  Future<DownloadedSong> _relocate(
    DownloadedSong item,
    Directory targetDir, {
    required bool retag,
  }) async {
    final source = File(item.audioPath);
    final ext = _extensionOf(source.path);
    await targetDir.create(recursive: true);
    final target = await _uniqueTarget(
      targetDir,
      item.song,
      ext,
      currentPath: source.path,
    );

    if (retag && ext == '.mp3') {
      final bytes = await _tagged(await source.readAsBytes(), item.song);
      await _writeAtomically(target, bytes);
      if (target.path != source.path) await _deleteQuietly(source);
    } else if (target.path != source.path) {
      try {
        await source.rename(target.path);
      } on FileSystemException {
        // Different volume — rename can't cross it, so copy then remove.
        await _writeAtomically(target, await source.readAsBytes());
        await _deleteQuietly(source);
      }
    }
    await _announceToMediaLibrary(target.path);

    return DownloadedSong(
      song: item.song,
      audioPath: target.path,
      downloadedAt: item.downloadedAt,
      bytes: await target.length(),
    );
  }

  /// "Title - Artist.ext" in [dir]. If another song already has that name,
  /// the song id is appended so neither overwrites the other.
  Future<File> _uniqueTarget(
    Directory dir,
    Song song,
    String ext, {
    String? currentPath,
  }) async {
    final base = _readableName(song);
    final preferred = File('${dir.path}/$base$ext');
    if (preferred.path == currentPath || !await preferred.exists()) {
      return preferred;
    }
    return File('${dir.path}/$base [${song.id}]$ext');
  }

  String _readableName(Song song) {
    final artists = song.artists
        .map((artist) => artist.name.trim())
        .where((name) => name.isNotEmpty)
        .join(', ');
    final raw = artists.isEmpty ? song.name : '${song.name} - $artists';
    final safe = _sanitizeFileName(raw);
    return safe.isEmpty ? '${song.id}' : safe;
  }

  /// Strips characters that are illegal in file names on Windows, macOS or
  /// Android's shared storage, and keeps the name to a sane length.
  String _sanitizeFileName(String input) {
    var name = input
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // Trailing dots/spaces are silently dropped by Windows, which would make
    // the file unreachable under the name we recorded.
    name = name.replaceAll(RegExp(r'[. ]+$'), '');
    // Count runes, not UTF-16 units, so a cut never splits a character.
    final runes = name.runes.toList();
    if (runes.length > 120) {
      name = String.fromCharCodes(runes.take(120)).trim();
    }
    return name;
  }

  Future<void> _writeAtomically(File target, List<int> bytes) async {
    final ext = _extensionOf(target.path);
    final stem = target.path.substring(0, target.path.length - ext.length);
    final part = File('$stem$_partMarker$ext');
    await part.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
  }

  /// Android: files written to shared storage don't show up in music apps
  /// until the media scanner sees them. No-op elsewhere.
  Future<void> _announceToMediaLibrary(String path) async {
    if (!Platform.isAndroid) return;
    try {
      await _systemChannel.invokeMethod<bool>('scanFile', {'path': path});
    } on Object {
      // Purely cosmetic for other apps; never fails a download.
    }
  }

  Future<void> _writeIndex(DownloadedSong item) async {
    final dir = await _indexDir();
    await dir.create(recursive: true);
    final file = File('${dir.path}/${item.song.id}.json');
    await file.writeAsString(jsonEncode(item.toJson()), flush: true);
  }

  Future<List<_IndexEntry>> _indexEntries({
    bool includeUnreadable = false,
  }) async {
    final entries = <_IndexEntry>[];
    for (final dir in await _indexDirs()) {
      try {
        if (!await dir.exists()) continue;
        await for (final entity in dir.list()) {
          if (entity is! File || !entity.path.endsWith('.json')) continue;
          try {
            final decoded = jsonDecode(await entity.readAsString());
            if (decoded is! Map<String, dynamic>) throw const FormatException();
            entries.add(_IndexEntry(entity, DownloadedSong.fromJson(decoded)));
          } on Object {
            if (includeUnreadable) {
              entries.add(_IndexEntry(entity, _unreadable));
            }
          }
        }
      } on Object {
        // One unreadable directory must not hide entries in the others.
      }
    }
    return entries;
  }

  static final _unreadable = DownloadedSong(
    song: const Song(id: 0, name: '', artists: [], album: '', coverUrl: ''),
    audioPath: '',
    downloadedAt: DateTime.fromMillisecondsSinceEpoch(0),
    bytes: 0,
  );

  /// App-private folder holding one JSON entry per downloaded song.
  Future<Directory> _indexDir() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/download_index');
  }

  /// The index folder plus the places older versions kept their JSON
  /// (next to the audio), so nothing downloaded before goes missing.
  Future<List<Directory>> _indexDirs() async {
    return [await _indexDir(), ...await _legacyDirs()];
  }

  /// Where audio is written: the user's chosen folder, or the default.
  Future<Directory> _audioDir() async {
    final custom = _customDirectory;
    if (custom != null && custom.isNotEmpty) return Directory(custom);
    return _defaultAudioDir();
  }

  /// On Android the app documents directory is private storage that no file
  /// manager can reach, so downloads were effectively trapped in the app.
  /// App-specific external storage (Android/data/<package>/files) is
  /// browsable and needs no permission.
  Future<Directory> _defaultAudioDir() async {
    if (Platform.isAndroid) {
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) return Directory('${external.path}/downloads');
      } on Object {
        // Fall through to the private documents directory.
      }
    }
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/downloads');
  }

  /// Folders older versions wrote to (audio and JSON side by side).
  Future<List<Directory>> _legacyDirs() async {
    final dirs = <Directory>[];
    final paths = <String>{};
    void add(Directory dir) {
      if (paths.add(dir.path)) dirs.add(dir);
    }

    try {
      final root = await getApplicationDocumentsDirectory();
      add(Directory('${root.path}/downloads'));
    } on Object {
      // Not resolvable on this platform.
    }
    if (Platform.isAndroid) {
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) add(Directory('${external.path}/downloads'));
      } on Object {
        // No external storage.
      }
    }
    return dirs;
  }

  /// Folders MuseHub owns outright, where sweeping loose files is safe.
  Future<List<Directory>> _ownedDirs() async {
    return [await _defaultAudioDir(), ...await _legacyDirs()];
  }

  bool _isAudioPath(String path) {
    return const ['.flac', '.m4a', '.aac', '.ogg', '.wav', '.mp3']
        .contains(_extensionOf(path));
  }

  String _extensionOf(String path) {
    final name = path.split(Platform.pathSeparator).last.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot).toLowerCase();
  }

  String _stem(String path) {
    final name = path.split(Platform.pathSeparator).last.split('/').last;
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  String _extensionForUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final ext in const ['.flac', '.m4a', '.aac', '.ogg', '.wav', '.mp3']) {
      if (path.endsWith(ext)) return ext;
    }
    return '.mp3';
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Ignore — best effort.
    }
  }
}

class _IndexEntry {
  const _IndexEntry(this.file, this.item);

  final File file;
  final DownloadedSong item;
}
