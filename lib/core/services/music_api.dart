import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

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

class _CachedJson {
  const _CachedJson(this.data, this.createdAt);

  final Map<String, dynamic> data;
  final DateTime createdAt;

  bool isFresh(Duration ttl) => DateTime.now().difference(createdAt) < ttl;
}

class MusicApi {
  MusicApi({
    http.Client? client,
    String baseUrl = defaultBaseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = _normalizeBaseUrl(baseUrl);

  static const defaultBaseUrl =
      'https://netease-cloud-music-api-five-roan-88.vercel.app';
  static const defaultResolverBaseUrl = '';
  static const _requestTimeout = Duration(seconds: 8);
  static const _cacheTtl = Duration(minutes: 10);
  static const _maxAttempts = 3;

  final http.Client _client;
  final Map<String, _CachedJson> _cache = {};
  String _baseUrl;
  String _resolverBaseUrl = defaultResolverBaseUrl;

  String get baseUrl => _baseUrl;
  String get resolverBaseUrl => _resolverBaseUrl;

  set baseUrl(String value) {
    _baseUrl = _normalizeBaseUrl(value);
  }

  set resolverBaseUrl(String value) {
    _resolverBaseUrl = _normalizeOptionalBaseUrl(value);
  }

  Future<HomeSnapshot> getHomeSnapshot() async {
    final bannersData =
        await _get('/banner', query: {'type': '2'}, allowCacheFallback: true);
    final newSongsData = await _get('/personalized/newsong',
        query: {'limit': '12'}, allowCacheFallback: true);
    final playlistsData = await _get('/personalized',
        query: {'limit': '12'}, allowCacheFallback: true);

    final banners = ((bannersData['banners'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BannerItem.fromJson)
        .where((item) => item.imageUrl.isNotEmpty)
        .toList();

    final newSongs = ((newSongsData['result'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .where((song) => song.id != 0)
        .toList();

    final playlists = ((playlistsData['result'] as List?) ?? const [])
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

  Future<List<Song>> searchSongs(String keyword,
      {int limit = 30, int offset = 0}) async {
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

  Future<String?> songUrl(Song song, {String level = 'higher'}) async {
    for (final candidateLevel in [level, 'exhigh', 'standard']) {
      final data = await _get(
        '/song/url/v1',
        query: {
          'id': '${song.id}',
          'level': candidateLevel,
          'encodeType': 'aac'
        },
      );
      final url = _readSongUrl(data);
      if (url != null) return url;
    }

    final data = await _get(
      '/song/url',
      query: {'id': '${song.id}', 'br': '128000'},
    );
    final url = _readSongUrl(data);
    if (url != null) return url;

    developer.log(
      'Official Netease URL unavailable for ${song.id}; trying Alger fallback',
      name: 'MuseHub.MusicApi',
    );
    return _resolveWithAlgerFallback(song);
  }

  String? _readSongUrl(Map<String, dynamic> data) {
    final items = data['data'];
    if (items is! List || items.isEmpty) return null;
    final first = items.first;
    if (first is! Map<String, dynamic>) return null;
    final url = first['url']?.toString();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  Future<String?> _resolveWithAlgerFallback(Song song) async {
    if (_resolverBaseUrl.isEmpty) return null;

    final uri = Uri.parse('$_resolverBaseUrl/unblock-music');
    final payload = {
      'id': song.id,
      'enabledSources': const ['migu', 'kugou', 'kuwo', 'pyncmd'],
      'songData': {
        'name': song.name,
        'artists': song.artists
            .map((artist) => {'id': artist.id, 'name': artist.name})
            .toList(),
        'album': {'name': song.album},
        'ar': song.artists
            .map((artist) => {'id': artist.id, 'name': artist.name})
            .toList(),
        'al': {'name': song.album},
      },
    };

    try {
      final response = await _client
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      final resolvedUrl = _readResolvedUrl(decoded);
      if (resolvedUrl == null) {
        developer.log(
          'Alger fallback returned no URL for ${song.id}: ${response.body}',
          name: 'MuseHub.MusicApi',
        );
      } else {
        developer.log(
          'Alger fallback resolved ${song.id}: $resolvedUrl',
          name: 'MuseHub.MusicApi',
        );
      }
      return resolvedUrl;
    } on Object catch (error) {
      developer.log(
        'Alger fallback failed for ${song.id}: $error',
        name: 'MuseHub.MusicApi',
      );
      return null;
    }
  }

  String? _readResolvedUrl(Map<String, dynamic> data) {
    final candidates = [
      data['url'],
      (data['data'] as Map?)?['url'],
      ((data['data'] as Map?)?['data'] as Map?)?['url'],
      (((data['data'] as Map?)?['data'] as Map?)?['data'] as Map?)?['url'],
    ];
    for (final candidate in candidates) {
      final url = candidate?.toString();
      if (url != null && url.isNotEmpty) {
        return url;
      }
    }
    return null;
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
    final trackIds =
        (((data['playlist'] as Map?)?['trackIds'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map((item) => int.tryParse('${item['id']}') ?? 0)
            .where((id) => id != 0)
            .take(60)
            .toList();
    return songDetails(trackIds);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
    bool allowCacheFallback = false,
  }) async {
    final cacheKey = _cacheKey(path, query);
    final cached = _cache[cacheKey];
    if (allowCacheFallback && cached != null && cached.isFresh(_cacheTtl)) {
      return cached.data;
    }

    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: {
      ...?query,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    });

    Object? lastError;
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final response = await _client.get(uri).timeout(_requestTimeout);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            throw const MusicApiException('Unexpected API response');
          }
          _cache[cacheKey] = _CachedJson(decoded, DateTime.now());
          return decoded;
        }

        final error = MusicApiException(
          'Music API request failed (${response.statusCode}): ${uri.host}${uri.path}',
        );
        if (!_shouldRetryStatus(response.statusCode) ||
            attempt == _maxAttempts) {
          throw error;
        }
        lastError = error;
      } on TimeoutException catch (error) {
        lastError = error;
      } on http.ClientException catch (error) {
        lastError = error;
      }

      if (attempt < _maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    if (allowCacheFallback && cached != null) {
      return cached.data;
    }

    throw MusicApiException(_formatNetworkError(uri, lastError));
  }

  bool _shouldRetryStatus(int statusCode) {
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  String _cacheKey(String path, Map<String, String>? query) {
    final sortedQuery = Map.fromEntries(
        (query ?? const <String, String>{}).entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)));
    return Uri(
            path: path,
            queryParameters: sortedQuery.isEmpty ? null : sortedQuery)
        .toString();
  }

  String _formatNetworkError(Uri uri, Object? error) {
    if (error is TimeoutException) {
      return 'Network timeout: ${uri.host}${uri.path}';
    }
    if (error is http.ClientException) {
      return 'Network unavailable: ${uri.host}${uri.path}';
    }
    if (error != null) {
      return 'Network request failed: ${uri.host}${uri.path} ($error)';
    }
    return 'Network request failed: ${uri.host}${uri.path}';
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return defaultBaseUrl;
    return _normalizeNonEmptyBaseUrl(trimmed);
  }

  static String _normalizeOptionalBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return _normalizeNonEmptyBaseUrl(trimmed);
  }

  static String _normalizeNonEmptyBaseUrl(String trimmed) {
    final withoutTrailingSlash = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    return withoutTrailingSlash.endsWith('/api.php')
        ? withoutTrailingSlash.substring(
            0, withoutTrailingSlash.length - '/api.php'.length)
        : withoutTrailingSlash;
  }
}
