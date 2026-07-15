import 'dart:convert';
import 'dart:io';

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

  Future<List<DownloadedSong>> listDownloads() async {
    try {
      final dir = await _downloadDir();
      if (!await dir.exists()) return const [];
      final results = <DownloadedSong>[];
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final decoded = jsonDecode(await entity.readAsString());
          if (decoded is! Map<String, dynamic>) continue;
          final item = DownloadedSong.fromJson(decoded);
          if (item.song.id == 0) continue;
          final audioFile = File(item.audioPath);
          if (!await audioFile.exists()) continue;
          if (await audioFile.length() < _minValidAudioBytes) {
            // Corrupt/truncated — drop it from the list and clean it up.
            await _deleteQuietly(audioFile);
            await _deleteQuietly(entity);
            continue;
          }
          results.add(item);
        } on Object {
          // Ignore corrupt metadata; the sweep below can remove it.
        }
      }
      results.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
      return results;
    } on Object {
      return const [];
    }
  }

  /// Sweep the download directory: remove corrupt/too-small audio files,
  /// leftover ".tmp" download residue, and orphaned metadata whose audio
  /// file is gone. Returns how many bad files were removed. Safe to run on
  /// startup — it never touches plausibly-complete downloads.
  Future<int> cleanUpCache() async {
    var removed = 0;
    try {
      final dir = await _downloadDir();
      if (!await dir.exists()) return 0;
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
          // Skip anything we can't read; don't let one bad file abort the sweep.
        }
      }
    } on Object {
      // Best-effort cleanup.
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
    try {
      final metadata = await _metadataFile(songId);
      if (!await metadata.exists()) return null;
      final decoded = jsonDecode(await metadata.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final item = DownloadedSong.fromJson(decoded);
      final audioFile = File(item.audioPath);
      if (!await audioFile.exists()) return null;
      // Guard against playing a corrupt/truncated cached file: if it's
      // implausibly small, delete it and its metadata and return null so
      // the player falls through to streaming instead of hitting the bad
      // file every time.
      final size = await audioFile.length();
      if (size < _minValidAudioBytes) {
        await _deleteQuietly(audioFile);
        await _deleteQuietly(metadata);
        return null;
      }
      return item.audioPath;
    } on Object {
      return null;
    }
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

    final response = await _client.get(Uri.parse(url)).timeout(
          const Duration(seconds: 60),
        );
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
    await metadata.writeAsString(jsonEncode(item.toJson()), flush: true);
    return item;
  }

  Future<void> deleteDownload(int songId) async {
    final metadata = await _metadataFile(songId);
    if (await metadata.exists()) {
      try {
        final decoded = jsonDecode(await metadata.readAsString());
        if (decoded is Map<String, dynamic>) {
          final item = DownloadedSong.fromJson(decoded);
          final audioFile = File(item.audioPath);
          if (await audioFile.exists()) await audioFile.delete();
        }
      } on Object {
        // Continue and delete metadata below.
      }
      await metadata.delete();
    }
  }

  Future<void> openDownloadDirectory() async {
    final dir = await _downloadDir();
    await dir.create(recursive: true);
    if (Platform.isMacOS) {
      await Process.run('open', [dir.path]);
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

  Future<Directory> _downloadDir() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/downloads');
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
