import 'playlist.dart';
import 'song.dart';

class BannerItem {
  const BannerItem({
    required this.imageUrl,
    required this.title,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      imageUrl: _normalizeImageUrl(
        json['pic'] ?? json['imageUrl'] ?? json['bigImageUrl'],
      ),
      title: '${json['typeTitle'] ?? json['titleColor'] ?? 'Featured'}',
    );
  }

  static String _normalizeImageUrl(dynamic value) {
    final url = '${value ?? ''}'.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://')) {
      return 'https://${url.substring('http://'.length)}';
    }
    return url;
  }

  final String imageUrl;
  final String title;
}

class HomeSnapshot {
  const HomeSnapshot({
    required this.banners,
    required this.newSongs,
    required this.playlists,
  });

  final List<BannerItem> banners;
  final List<Song> newSongs;
  final List<MusicPlaylist> playlists;
}
