import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
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

  static const defaultBaseUrl = 'https://music.163.com/api';
  static const legacyBaseUrl =
      'https://netease-cloud-music-api-five-roan-88.vercel.app';
  static const defaultResolverBaseUrl = '';
  static const _requestTimeout = Duration(seconds: 8);
  static const _probeTimeout = Duration(seconds: 6);
  static const _resolverTimeout = Duration(seconds: 45);
  static const _cacheTtl = Duration(minutes: 10);
  static const _maxAttempts = 3;
  static const _minLikelyAudioBytes = 128 * 1024;

  final http.Client _client;
  final Map<String, _CachedJson> _cache = {};
  String _baseUrl;
  String _resolverBaseUrl = defaultResolverBaseUrl;
  DateTime? _resolverUnavailableUntil;

  String get baseUrl => _baseUrl;
  String get resolverBaseUrl => _resolverBaseUrl;
  bool get _usesDirectNetease => _baseUrl == defaultBaseUrl;

  set baseUrl(String value) {
    _baseUrl = _normalizeBaseUrl(value);
  }

  set resolverBaseUrl(String value) {
    _resolverBaseUrl = _normalizeOptionalBaseUrl(value);
    _resolverUnavailableUntil = null;
  }

  Future<HomeSnapshot> getHomeSnapshot() async {
    final bannersData = await _getWithFallback(
      _usesDirectNetease
          ? const [
              _ApiEndpoint('/v2/banner/get', query: {'clientType': 'pc'}),
              _ApiEndpoint('/banner',
                  query: {'type': '2'}, useLegacyBase: true),
            ]
          : const [
              _ApiEndpoint('/banner', query: {'type': '2'}),
            ],
      allowCacheFallback: true,
    );
    final newSongsData = await _get('/personalized/newsong',
        query: {'limit': '12'}, allowCacheFallback: true);
    final playlistsData = await _getWithFallback(
      _usesDirectNetease
          ? const [
              _ApiEndpoint('/personalized/playlist', query: {'limit': '12'}),
              _ApiEndpoint('/personalized',
                  query: {'limit': '12'}, useLegacyBase: true),
            ]
          : const [
              _ApiEndpoint('/personalized', query: {'limit': '12'}),
            ],
      allowCacheFallback: true,
    );

    final banners = ((bannersData['banners'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(BannerItem.fromJson)
        .where((item) => item.imageUrl.isNotEmpty)
        .toList();

    final newSongs = await _hydrateMissingSongDetails(
      ((newSongsData['result'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .where((song) => song.id != 0)
          .toList(),
    );

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
    final endpoints = _usesDirectNetease
        ? [
            _ApiEndpoint(
              '/search/get',
              query: {
                's': keyword,
                'type': '1',
                'limit': '$limit',
                'offset': '$offset',
              },
            ),
            _ApiEndpoint(
              '/cloudsearch',
              query: {
                'keywords': keyword,
                'type': '1',
                'limit': '$limit',
                'offset': '$offset',
              },
              useLegacyBase: true,
            ),
          ]
        : [
            _ApiEndpoint(
              '/cloudsearch',
              query: {
                'keywords': keyword,
                'type': '1',
                'limit': '$limit',
                'offset': '$offset',
              },
            ),
          ];
    final songs = await _searchSongsFromAll(endpoints);
    return _hydrateMissingSongDetails(songs);
  }

  Future<List<String>> searchSuggestions(String keyword) async {
    if (keyword.trim().isEmpty) return const [];
    final data = await _getWithFallback(
      _usesDirectNetease
          ? [
              _ApiEndpoint('/search/suggest/web', query: {'s': keyword}),
              _ApiEndpoint(
                '/search/suggest',
                query: {'keywords': keyword},
                useLegacyBase: true,
              ),
            ]
          : [
              _ApiEndpoint('/search/suggest', query: {'keywords': keyword}),
            ],
    );
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
    if (_usesDirectNetease) {
      final directUrl = await _resolveWithDirectNetease(song);
      if (directUrl != null) return directUrl;

      final compatibleUrl = await _resolveWithCompatibleApi(
        song,
        level: level,
        useLegacyBase: true,
      );
      if (compatibleUrl != null) return compatibleUrl;
    } else {
      final compatibleUrl = await _resolveWithCompatibleApi(song, level: level);
      if (compatibleUrl != null) return compatibleUrl;
    }

    developer.log(
      'Primary URL unavailable for ${song.id}; trying Alger fallback',
      name: 'MuseHub.MusicApi',
    );
    final resolvedUrl = await _resolveWithAlgerFallback(song);
    if (resolvedUrl != null) return resolvedUrl;

    return null;
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

  Future<String?> _resolveWithDirectNetease(Song song) async {
    final data = await _getOrNull(
      '/song/enhance/player/url',
      query: {
        'id': '${song.id}',
        'ids': '[${song.id}]',
        'br': '320000',
      },
    );
    if (data == null) return null;
    return _validatedAudioUrl(_readSongUrl(data), durationMs: song.durationMs);
  }

  Future<String?> _resolveWithCompatibleApi(
    Song song, {
    required String level,
    bool useLegacyBase = false,
  }) async {
    for (final candidateLevel in [level, 'exhigh', 'standard']) {
      final data = await _getOrNull(
        '/song/url/v1',
        query: {
          'id': '${song.id}',
          'level': candidateLevel,
          'encodeType': 'aac',
        },
        useLegacyBase: useLegacyBase,
      );
      if (data != null) {
        final url = _readSongUrl(data);
        final validatedUrl = await _validatedAudioUrl(
          url,
          durationMs: song.durationMs,
        );
        if (validatedUrl != null) return validatedUrl;
      }
    }

    final data = await _getOrNull(
      '/song/url',
      query: {'id': '${song.id}', 'br': '128000'},
      useLegacyBase: useLegacyBase,
    );
    if (data == null) return null;
    return _validatedAudioUrl(_readSongUrl(data), durationMs: song.durationMs);
  }

  Future<String?> _resolveWithAlgerFallback(Song song) async {
    if (_resolverBaseUrl.isEmpty) return null;
    final unavailableUntil = _resolverUnavailableUntil;
    if (unavailableUntil != null && DateTime.now().isBefore(unavailableUntil)) {
      return null;
    }

    final uri = Uri.parse('$_resolverBaseUrl/unblock-music');
    final payload = {
      'id': song.id,
      'enabledSources': const [
        'pyncmd',
        'kugou',
        'kuwo',
        'migu',
        'qq',
        'bilibili',
      ],
      'songData': {
        'name': song.name,
        'duration': song.durationMs,
        'durationMs': song.durationMs,
        'dt': song.durationMs,
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
          .timeout(_resolverTimeout);
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
      return _validatedAudioUrl(resolvedUrl, durationMs: song.durationMs);
    } on Object catch (error) {
      developer.log(
        'Alger fallback failed for ${song.id}: $error',
        name: 'MuseHub.MusicApi',
      );
      if (_isLocalResolverUrl(uri)) {
        _resolverUnavailableUntil = DateTime.now().add(
          const Duration(minutes: 2),
        );
      }
      return null;
    }
  }

  bool _isLocalResolverUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '::1' ||
        host == '10.0.2.2';
  }

  Future<List<Song>> _searchSongsFromAll(List<_ApiEndpoint> endpoints) async {
    final byId = <int, Song>{};
    Object? lastError;

    for (final endpoint in endpoints) {
      try {
        final data = await _get(
          endpoint.path,
          query: endpoint.query,
          useLegacyBase: endpoint.useLegacyBase,
        );
        final songs =
            (((data['result'] as Map?)?['songs'] as List?) ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(Song.fromJson)
                .where((song) => song.id != 0);
        for (final song in songs) {
          byId.putIfAbsent(song.id, () => song);
        }
      } on Object catch (error) {
        lastError = error;
      }
    }

    if (byId.isEmpty && lastError != null) {
      if (lastError is MusicApiException) throw lastError;
      throw MusicApiException('$lastError');
    }
    return byId.values.toList();
  }

  Future<String?> _validatedAudioUrl(String? url, {int? durationMs}) async {
    if (url == null || url.isEmpty) return null;
    if (kIsWeb) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final probeResult = await _probeAudioUrl(uri, durationMs: durationMs);
    if (probeResult != false) return url;
    developer.log(
      'Rejected non-playable audio URL: $url',
      name: 'MuseHub.MusicApi',
    );
    return null;
  }

  Future<bool?> _probeAudioUrl(Uri uri, {int? durationMs}) async {
    try {
      final response = await _client
          .head(uri, headers: _audioProbeHeaders)
          .timeout(_probeTimeout);
      final result = _audioProbeResult(
        response.statusCode,
        response.headers,
        isRangeProbe: false,
        durationMs: durationMs,
      );
      if (result != null) return result;
    } on Object {
      // Some music CDNs reject HEAD; fall through to a byte-range probe.
    }

    try {
      final request = http.Request('GET', uri)
        ..headers.addAll(_audioProbeHeaders)
        ..headers['range'] = 'bytes=0-0';
      final response = await _client.send(request).timeout(_probeTimeout);
      await response.stream.drain<void>();
      return _audioProbeResult(
        response.statusCode,
        response.headers,
        isRangeProbe: true,
        durationMs: durationMs,
      );
    } on Object {
      return null;
    }
  }

  bool? _audioProbeResult(
    int statusCode,
    Map<String, String> headers, {
    required bool isRangeProbe,
    int? durationMs,
  }) {
    if (statusCode < 200 || statusCode >= 300) return false;
    final contentType = (headers['content-type'] ?? '').toLowerCase();
    if (contentType.contains('json') ||
        contentType.contains('text/html') ||
        contentType.startsWith('text/plain')) {
      return false;
    }
    final contentLength = int.tryParse(headers['content-length'] ?? '');
    final minimumBytes = _minimumExpectedAudioBytes(durationMs);
    if (!isRangeProbe && contentLength != null && contentLength > 0) {
      if (contentLength < minimumBytes) return false;
    }
    if (!isRangeProbe &&
        contentLength == null &&
        minimumBytes > _minLikelyAudioBytes) {
      return null;
    }
    if (!isRangeProbe && contentLength == 0) {
      return false;
    }
    if (contentType.isEmpty) {
      return contentLength == null || isRangeProbe
          ? null
          : contentLength >= minimumBytes;
    }
    return contentType.startsWith('audio/') ||
        contentType.contains('octet-stream') ||
        contentType.contains('mpegurl') ||
        contentType.contains('mp4') ||
        contentType.contains('flac');
  }

  int _minimumExpectedAudioBytes(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return _minLikelyAudioBytes;
    final seconds = durationMs / 1000;
    final expectedLowBitrateBytes = (seconds * 8000).round();
    return expectedLowBitrateBytes < _minLikelyAudioBytes
        ? _minLikelyAudioBytes
        : expectedLowBitrateBytes;
  }

  static const Map<String, String> _audioProbeHeaders = {
    'accept': '*/*',
    'user-agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0 Safari/537.36',
  };

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
    final data = await _getWithFallback(
      _usesDirectNetease
          ? [
              _ApiEndpoint('/song/detail/', query: {'ids': jsonEncode(ids)}),
              _ApiEndpoint(
                '/song/detail',
                query: {'ids': ids.join(',')},
                useLegacyBase: true,
              ),
            ]
          : [
              _ApiEndpoint('/song/detail', query: {'ids': ids.join(',')}),
            ],
    );
    return ((data['songs'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .where((song) => song.id != 0)
        .toList();
  }

  Future<List<Song>> _hydrateMissingSongDetails(List<Song> songs) async {
    final missingIds = songs
        .where((song) => song.coverUrl.isEmpty || song.artists.isEmpty)
        .map((song) => song.id)
        .toList();
    if (missingIds.isEmpty) return songs;

    try {
      final detailedSongs = await songDetails(missingIds);
      final detailsById = {for (final song in detailedSongs) song.id: song};
      return [
        for (final song in songs)
          detailsById[song.id] == null
              ? song
              : song.mergeDetails(detailsById[song.id]!),
      ];
    } on Object catch (error) {
      developer.log(
        'Song detail hydration failed: $error',
        name: 'MuseHub.MusicApi',
      );
      return songs;
    }
  }

  Future<List<LyricLine>> lyrics(int id) async {
    final data = await _getWithFallback(
      _usesDirectNetease
          ? [
              _ApiEndpoint(
                '/song/lyric',
                query: {'id': '$id', 'lv': '-1', 'kv': '-1', 'tv': '-1'},
              ),
              _ApiEndpoint('/lyric/new',
                  query: {'id': '$id'}, useLegacyBase: true),
            ]
          : [
              _ApiEndpoint('/lyric/new', query: {'id': '$id'}),
            ],
    );
    final raw = ((data['lrc'] as Map?)?['lyric'] ?? '').toString();
    return parseLrc(raw);
  }

  Future<List<Song>> playlistSongs(int id) async {
    final data = await _getWithFallback(
      _usesDirectNetease
          ? [
              _ApiEndpoint('/playlist/detail', query: {'id': '$id'}),
              _ApiEndpoint(
                '/playlist/detail',
                query: {'id': '$id'},
                useLegacyBase: true,
              ),
            ]
          : [
              _ApiEndpoint('/playlist/detail', query: {'id': '$id'}),
            ],
    );
    final playlist = (data['playlist'] as Map?) ?? (data['result'] as Map?);
    final tracks = (playlist?['tracks'] as List?) ?? const [];
    if (tracks.isNotEmpty) {
      return _hydrateMissingSongDetails(
        tracks
            .whereType<Map<String, dynamic>>()
            .take(60)
            .map(Song.fromJson)
            .where((song) => song.id != 0)
            .toList(),
      );
    }
    final trackIds = ((playlist?['trackIds'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) => int.tryParse('${item['id']}') ?? 0)
        .where((id) => id != 0)
        .take(60)
        .toList();
    return songDetails(trackIds);
  }

  Future<Map<String, dynamic>> _getWithFallback(
    List<_ApiEndpoint> endpoints, {
    bool allowCacheFallback = false,
  }) async {
    Object? lastError;
    for (final endpoint in endpoints) {
      try {
        return await _get(
          endpoint.path,
          query: endpoint.query,
          allowCacheFallback: allowCacheFallback,
          useLegacyBase: endpoint.useLegacyBase,
        );
      } on Object catch (error) {
        lastError = error;
      }
    }
    if (lastError is MusicApiException) throw lastError;
    throw MusicApiException('$lastError');
  }

  Future<Map<String, dynamic>?> _getOrNull(
    String path, {
    Map<String, String>? query,
    bool useLegacyBase = false,
  }) async {
    try {
      return await _get(path, query: query, useLegacyBase: useLegacyBase);
    } on Object catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
    bool allowCacheFallback = false,
    bool useLegacyBase = false,
  }) async {
    final cacheKey = _cacheKey(path, query, useLegacyBase: useLegacyBase);
    final cached = _cache[cacheKey];
    if (allowCacheFallback && cached != null && cached.isFresh(_cacheTtl)) {
      return cached.data;
    }

    final baseUrl = useLegacyBase ? legacyBaseUrl : _baseUrl;
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: {
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

  String _cacheKey(
    String path,
    Map<String, String>? query, {
    required bool useLegacyBase,
  }) {
    final sortedQuery = Map.fromEntries(
        (query ?? const <String, String>{}).entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)));
    return Uri(
            host: useLegacyBase ? 'legacy' : 'primary',
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

  static String normalizeBaseUrl(String value) => _normalizeBaseUrl(value);

  static String normalizeOptionalBaseUrl(String value) =>
      _normalizeOptionalBaseUrl(value);

  static String _normalizeNonEmptyBaseUrl(String trimmed) {
    final withoutTrailingSlash = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final normalized = withoutTrailingSlash.endsWith('/api.php')
        ? withoutTrailingSlash.substring(
            0, withoutTrailingSlash.length - '/api.php'.length)
        : withoutTrailingSlash;
    return normalized == legacyBaseUrl ? defaultBaseUrl : normalized;
  }
}

class _ApiEndpoint {
  const _ApiEndpoint(
    this.path, {
    this.query,
    this.useLegacyBase = false,
  });

  final String path;
  final Map<String, String>? query;
  final bool useLegacyBase;
}
