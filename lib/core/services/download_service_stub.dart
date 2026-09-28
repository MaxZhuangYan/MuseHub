import '../models/song.dart';
import 'download_models.dart';
import 'music_api.dart';

class DownloadService {
  DownloadService({
    MusicApi? api,
    dynamic client,
  });

  String? get customDirectory => null;

  bool get canChooseDownloadDirectory => false;

  Future<String?> restoreCustomDirectory(String? savedPath) async => null;

  Future<String?> pickCustomDirectory() async => null;

  Future<String?> useSharedMusicDirectory() async => null;

  Future<void> useDefaultDirectory() async {}

  Future<List<DownloadedSong>> listDownloads() async => const [];

  Future<String?> localPathForSong(int songId) async => null;

  Future<DownloadedSong> downloadSong(Song song) {
    throw const MusicApiException(
        'Downloads are not available on this platform.');
  }

  Future<void> deleteDownload(int songId) async {}

  Future<int> cleanUpCache() async => 0;

  Future<int> migrateLegacyDownloads() async => 0;

  Future<int> moveDownloadsToCurrentDirectory() async => 0;

  Future<String> downloadDirectoryPath() async => '';

  bool get canOpenDownloadDirectory => false;

  Future<void> openDownloadDirectory() {
    throw const MusicApiException(
      'Opening the download folder is not available on this platform.',
    );
  }
}
