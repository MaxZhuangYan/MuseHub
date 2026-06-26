import 'playlist.dart';
import 'song.dart';

class BannerItem {
  const BannerItem({
    required this.imageUrl,
    required this.title,
  });

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      imageUrl: '${json['pic'] ?? json['imageUrl'] ?? ''}',
      title: '${json['typeTitle'] ?? json['titleColor'] ?? 'Featured'}',
    );
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
