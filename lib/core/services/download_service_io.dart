import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/song.dart';
import 'download_models.dart';
import 'music_api.dart';

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

  Future<List<DownloadedSong>> listDownloads() async {
    final results = <DownloadedSong>[];
    final seen = <int>{};
    for (final dir in await _allDownloadDirs()) {
      try {
        if (!await dir.exists()) continue;
        await for (final entity in dir.list()) {
          if (entity is! File || !entity.path.endsWith('.json')) continue;
          try {
            final decoded = jsonDecode(await entity.readAsString());
            if (decoded is! Map<String, dynamic>) continue;
            final item = DownloadedSong.fromJson(decoded);
            if (item.song.id == 0 || seen.contains(item.song.id)) continue;
            final audioFile = File(item.audioPath);
            if (!await audioFile.exists()) continue;
            if (await audioFile.length() < _minValidAudioBytes) {
              // Corrupt/truncated — drop it from the list and clean it up.
              await _deleteQuietly(audioFile);
              await _deleteQuietly(entity);
              continue;
            }
            seen.add(item.song.id);
            results.add(item);
          } on Object {
            // Ignore corrupt metadata; the sweep below can remove it.
          }
        }
      } on Object {
        // One unreadable directory must not hide downloads in the others.
      }
    }
    results.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return results;
  }

  /// Sweep the download directories: remove corrupt/too-small audio files,
  /// leftover ".tmp" download residue, and orphaned metadata whose audio
  /// file is gone. Returns how many bad files were removed. Safe to run on
  /// startup — it never touches plausibly-complete downloads.
  Future<int> cleanUpCache() async {
    var removed = 0;
    for (final dir in await _allDownloadDirs()) {
      try {
        if (!await dir.exists()) continue;
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final path = entity.path;
          try {
            // Interrupted-download residue.
            if (path.endsWith('.tmp') || path.endsWith('.download')) {
              await _deleteQuietly(entity);
              removed++;
              continue;
            }
            if (path.endsWith('.json')) {
              final decoded = jsonDecode(await entity.readAsString());
              if (decoded is! Map<String, dynamic>) {
                await _deleteQuietly(entity);
                removed++;
                continue;
              }
              final item = DownloadedSong.fromJson(decoded);
              final audioFile = File(item.audioPath);
              final gone = !await audioFile.exists();
              if (gone || await audioFile.length() < _minValidAudioBytes) {
                if (!gone) await _deleteQuietly(audioFile);
                await _deleteQuietly(entity);
                removed++;
              }
              continue;
            }
            // A bare audio file that's implausibly small.
            if (_isAudioPath(path) &&
                await entity.length() < _minValidAudioBytes) {
              await _deleteQuietly(entity);
              removed++;
            }
          } on Object {
            // Skip anything we can't read; one bad file must not abort the sweep.
          }
        }
      } on Object {
        // Best-effort cleanup.
      }
    }
    return removed;
  }

  bool _isAudioPath(String path) {
    final lower = path.toLowerCase();
    for (final ext in const ['.flac', '.m4a', '.aac', '.ogg', '.wav', '.mp3']) {
      if (lower.endsWith(ext)) return true;
    }
    return false;
  }

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Ignore — best effort.
    }
  }

  Future<String?> localPathForSong(int songId) async {
    for (final dir in await _allDownloadDirs()) {
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

    final audioFile = await _audioFile(hydrated.id, url);
    await audioFile.parent.create(recursive: true);
    await audioFile.writeAsBytes(response.bodyBytes, flush: true);

    final item = DownloadedSong(
      song: hydrated,
      audioPath: audioFile.path,
      downloadedAt: DateTime.now(),
      bytes: response.bodyBytes.length,
    );
    final metadata = await _metadataFile(hydrated.id);
    await metadata.parent.create(recursive: true);
    await metadata.writeAsString(jsonEncode(item.toJson()), flush: true);
    return item;
  }

  Future<void> deleteDownload(int songId) async {
    for (final dir in await _allDownloadDirs()) {
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

  /// Absolute path of the folder downloads are written to, for showing the
  /// user where their files are on platforms that have no "reveal in file
  /// manager" equivalent.
  Future<String> downloadDirectoryPath() async {
    final dir = await _downloadDir();
    return dir.path;
  }

  /// Whether this platform can open the download folder in a file manager.
  /// Android/iOS have no reliable way to do that, so the UI shows the path
  /// instead of offering a button that always fails.
  bool get canOpenDownloadDirectory =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  static const _systemChannel = MethodChannel('musehub/system');

  Future<void> openDownloadDirectory() async {
    final dir = await _downloadDir();
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

  /// Where new downloads are written.
  ///
  /// On Android the app documents directory is private storage: the user
  /// cannot reach it with a file manager, so downloaded songs were
  /// effectively trapped inside the app. App-specific external storage
  /// (Android/data/<package>/files) is browsable and needs no permission,
  /// so downloads land somewhere the user can actually get at them.
  Future<Directory> _downloadDir() async {
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

  /// Every directory that may hold downloads — the current one plus older
  /// locations, so songs downloaded by a previous version stay visible and
  /// playable instead of silently disappearing.
  Future<List<Directory>> _allDownloadDirs() async {
    final dirs = <Directory>[];
    final paths = <String>{};
    Future<void> add(Future<Directory?> Function() resolve) async {
      try {
        final dir = await resolve();
        if (dir != null && paths.add(dir.path)) dirs.add(dir);
      } on Object {
        // A location we can't resolve on this platform is simply skipped.
      }
    }

    await add(_downloadDir);
    await add(() async {
      final root = await getApplicationDocumentsDirectory();
      return Directory('${root.path}/downloads');
    });
    return dirs;
  }

  Future<File> _metadataFile(int songId) async {
    final dir = await _downloadDir();
    return File('${dir.path}/$songId.json');
  }

  Future<File> _audioFile(int songId, String url) async {
    final dir = await _downloadDir();
    return File('${dir.path}/$songId${_extensionForUrl(url)}');
  }

  String _extensionForUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    for (final ext in const ['.flac', '.m4a', '.aac', '.ogg', '.wav', '.mp3']) {
      if (path.endsWith(ext)) return ext;
    }
    return '.mp3';
  }
}
