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
    final albumJson = json['al'] ?? json['album'] ?? nestedSong?['album'] ?? {};
    final artistsJson =
        json['ar'] ?? json['artists'] ?? nestedSong?['artists'] ?? [];
    final songJson = nestedSong ?? json;
    final coverUrl =
        json['picUrl'] ?? (albumJson is Map ? albumJson['picUrl'] : null);

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
      coverUrl: '${coverUrl ?? ''}',
      durationMs: _readNullableInt(
          json['dt'] ?? json['duration'] ?? songJson['duration']),
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
