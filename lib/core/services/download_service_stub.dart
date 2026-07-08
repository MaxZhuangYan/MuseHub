import '../models/song.dart';
import 'download_models.dart';
import 'music_api.dart';

class DownloadService {
  DownloadService({
    MusicApi? api,
    dynamic client,
  });

  Future<List<DownloadedSong>> listDownloads() async => const [];

  Future<String?> localPathForSong(int songId) async => null;

  Future<DownloadedSong> downloadSong(Song song) {
    throw const MusicApiException('Downloads are not available on this platform.');
  }

  Future<void> deleteDownload(int songId) async {}
}
