import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/home_snapshot.dart';
import '../models/lyric_line.dart';
import '../models/playlist.dart';
import '../models/song.dart';

class MusicApiException implements Exception {
  const MusicApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MusicApi {
  MusicApi({
    http.Client? client,
    String baseUrl = defaultBaseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = _normalizeBaseUrl(baseUrl);

  static const defaultBaseUrl = 'https://netease-cloud-music-api-five-roan-88.vercel.app';

  final http.Client _client;
  String _baseUrl;

  String get baseUrl => _baseUrl;

  set baseUrl(String value) {
    _baseUrl = _normalizeBaseUrl(value);
  }

  Future<HomeSnapshot> getHomeSnapshot() async {
    final results = await Future.wait([
      _get('/banner', query: {'type': '2'}),
      _get('/personalized/newsong', query: {'limit': '12'}),
      _get('/personalized', query: {'limit': '12'}),
    ]);

    final banners = ((results[0]['banners'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BannerItem.fromJson)
        .where((item) => item.imageUrl.isNotEmpty)
        .toList();

    final newSongs = ((results[1]['result'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .where((song) => song.id != 0)
        .toList();

    final playlists = ((results[2]['result'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MusicPlaylist.fromJson)
        .where((playlist) => playlist.id != 0)
        .toList();

    return HomeSnapshot(
      banners: banners,
      newSongs: newSongs,
      playlists: playlists,
    );
  }

  Future<List<Song>> searchSongs(String keyword, {int limit = 30, int offset = 0}) async {
    final data = await _get(
      '/cloudsearch',
      query: {
        'keywords': keyword,
        'type': '1',
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    return (((data['result'] as Map?)?['songs'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .where((song) => song.id != 0)
        .toList();
  }

  Future<List<String>> searchSuggestions(String keyword) async {
    if (keyword.trim().isEmpty) return const [];
    final data = await _get('/search/suggest', query: {'keywords': keyword});
    final result = data['result'] as Map<String, dynamic>? ?? {};
    final names = <String>{};

    for (final key in const ['songs', 'artists', 'albums']) {
      final items = result[key];
      if (items is List) {
        for (final item in items.whereType<Map<String, dynamic>>()) {
          final name = '${item['name'] ?? ''}'.trim();
          if (name.isNotEmpty) names.add(name);
        }
      }
    }

    return names.take(10).toList();
  }

  Future<String?> songUrl(int id, {String level = 'higher'}) async {
    final data = await _get(
      '/song/url/v1',
      query: {'id': '$id', 'level': level, 'encodeType': 'aac'},
    );
    final items = data['data'];
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map<String, dynamic>) return null;
    final url = first['url']?.toString();
    return url == null || url.isEmpty ? null : url;
  }

  Future<List<Song>> songDetails(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final data = await _get('/song/detail', query: {'ids': ids.join(',')});
    return ((data['songs'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .where((song) => song.id != 0)
        .toList();
  }

  Future<List<LyricLine>> lyrics(int id) async {
    final data = await _get('/lyric/new', query: {'id': '$id'});
    final raw = ((data['lrc'] as Map?)?['lyric'] ?? '').toString();
    return parseLrc(raw);
  }

  Future<List<Song>> playlistSongs(int id) async {
    final data = await _get('/playlist/detail', query: {'id': '$id'});
    final trackIds = (((data['playlist'] as Map?)?['trackIds'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => int.tryParse('${item['id']}') ?? 0)
        .where((id) => id != 0)
        .take(60)
        .toList();
    return songDetails(trackIds);
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: {
      ...?query,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MusicApiException('Music API request failed (${response.statusCode}): ${uri.host}${uri.path}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const MusicApiException('Unexpected API response');
    }
    return decoded;
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return defaultBaseUrl;
    final withoutTrailingSlash = trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    return withoutTrailingSlash.endsWith('/api.php')
        ? withoutTrailingSlash.substring(0, withoutTrailingSlash.length - '/api.php'.length)
        : withoutTrailingSlash;
  }
}
