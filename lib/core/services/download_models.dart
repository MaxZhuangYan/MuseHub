import '../models/artist.dart';
import '../models/song.dart';

class DownloadedSong {
  const DownloadedSong({
    required this.song,
    required this.audioPath,
    required this.downloadedAt,
    required this.bytes,
  });

  factory DownloadedSong.fromJson(Map<String, dynamic> json) {
    return DownloadedSong(
      song: Song(
        id: _readInt(json['id']),
        name: json['name']?.toString() ?? '',
        artists: ((json['artists'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(Artist.fromJson)
            .toList(),
        album: json['album']?.toString() ?? '',
        coverUrl: json['coverUrl']?.toString() ?? '',
        durationMs: _readNullableInt(json['durationMs']),
      ),
      audioPath: json['audioPath']?.toString() ?? '',
      downloadedAt:
          DateTime.tryParse(json['downloadedAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
      bytes: _readInt(json['bytes']),
    );
  }

  final Song song;
  final String audioPath;
  final DateTime downloadedAt;
  final int bytes;

  Map<String, dynamic> toJson() {
    return {
      'id': song.id,
      'name': song.name,
      'artists': [
        for (final artist in song.artists)
          {'id': artist.id, 'name': artist.name},
      ],
      'album': song.album,
      'coverUrl': song.coverUrl,
      'durationMs': song.durationMs,
      'audioPath': audioPath,
      'downloadedAt': downloadedAt.toIso8601String(),
      'bytes': bytes,
    };
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
}
