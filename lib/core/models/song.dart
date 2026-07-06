import 'artist.dart';

class Song {
  const Song({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.coverUrl,
    this.durationMs,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final nestedSong = json['song'] is Map<String, dynamic>
        ? json['song'] as Map<String, dynamic>
        : null;
    final albumJson = json['al'] ??
        json['album'] ??
        nestedSong?['al'] ??
        nestedSong?['album'] ??
        {};
    final artistsJson = json['ar'] ??
        json['artists'] ??
        nestedSong?['ar'] ??
        nestedSong?['artists'] ??
        [];
    final songJson = nestedSong ?? json;
    final coverUrl = _normalizeImageUrl(
      json['picUrl'] ??
          json['coverImgUrl'] ??
          songJson['picUrl'] ??
          songJson['coverImgUrl'] ??
          (albumJson is Map
              ? albumJson['picUrl'] ??
                  albumJson['blurPicUrl'] ??
                  albumJson['coverImgUrl']
              : null),
    );

    return Song(
      id: _readInt(json['id'] ?? songJson['id']),
      name: '${json['name'] ?? songJson['name'] ?? ''}',
      artists: artistsJson is List
          ? artistsJson
              .whereType<Map<String, dynamic>>()
              .map(Artist.fromJson)
              .toList()
          : const [],
      album: '${albumJson is Map ? albumJson['name'] ?? '' : ''}',
      coverUrl: coverUrl,
      durationMs: _readNullableInt(
        json['dt'] ??
            json['duration'] ??
            songJson['dt'] ??
            songJson['duration'],
      ),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  static int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse('$value');
  }

  static String _normalizeImageUrl(dynamic value) {
    final url = '${value ?? ''}'.trim();
    if (url.isEmpty) return '';
    if (url.startsWith('http://')) {
      return 'https://${url.substring('http://'.length)}';
    }
    return url;
  }

  Song mergeDetails(Song details) {
    if (id != details.id) return this;
    return Song(
      id: id,
      name: details.name.isNotEmpty ? details.name : name,
      artists: details.artists.isNotEmpty ? details.artists : artists,
      album: details.album.isNotEmpty ? details.album : album,
      coverUrl: details.coverUrl.isNotEmpty ? details.coverUrl : coverUrl,
      durationMs: details.durationMs ?? durationMs,
    );
  }

  final int id;
  final String name;
  final List<Artist> artists;
  final String album;
  final String coverUrl;
  final int? durationMs;

  String get artistText {
    if (artists.isEmpty) return 'Unknown artist';
    return artists
        .map((artist) => artist.name)
        .where((name) => name.isNotEmpty)
        .join(' / ');
  }
}
