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

  Future<List<DownloadedSong>> listDownloads() async {
    final dir = await _downloadDir();
    if (!await dir.exists()) return const [];
    final results = <DownloadedSong>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is! Map<String, dynamic>) continue;
        final item = DownloadedSong.fromJson(decoded);
        if (item.song.id != 0 && await File(item.audioPath).exists()) {
          results.add(item);
        }
      } on Object {
        // Ignore corrupt metadata; a later cleanup can remove it.
      }
    }
    results.sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));
    return results;
  }

  Future<String?> localPathForSong(int songId) async {
    final metadata = await _metadataFile(songId);
    if (!await metadata.exists()) return null;
    try {
      final decoded = jsonDecode(await metadata.readAsString());
      if (decoded is! Map<String, dynamic>) return null;
      final item = DownloadedSong.fromJson(decoded);
      if (await File(item.audioPath).exists()) return item.audioPath;
    } on Object {
      return null;
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

    final response = await _client.get(Uri.parse(url)).timeout(
          const Duration(seconds: 60),
        );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicApiException('Download failed (${response.statusCode}).');
    }
    if (response.bodyBytes.isEmpty) {
      throw const MusicApiException('Downloaded audio is empty.');
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
