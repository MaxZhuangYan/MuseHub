import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import 'models/muse_user.dart';
import 'models/song.dart';
import 'services/download_service.dart';
import 'services/musehub_server_api.dart';
import 'services/music_api.dart';

class AppState extends ChangeNotifier {
  AppState(this.api, this.serverApi, this.downloadService);

  final MusicApi api;
  final MuseHubServerApi serverApi;
  final DownloadService downloadService;

  static const _apiBaseUrlKey = 'apiBaseUrl';
  static const _resolverBaseUrlKey = 'resolverBaseUrl';
  static const _serverBaseUrlKey = 'serverBaseUrl';
  static const _sessionTokenKey = 'sessionToken';
  static const _localeKey = 'locale';
  static const _favoritesKey = 'favorites';
  static const _favoriteTrackIdsKey = 'favoriteTrackIds';
  final Set<int> _favoriteIds = {};
  final Map<int, String> _favoriteTrackIdsBySongId = {};
  final Map<int, DownloadedSong> _downloads = {};
  final Set<int> _downloadingIds = {};
  String _apiBaseUrl = MusicApi.defaultBaseUrl;
  String _resolverBaseUrl = _defaultResolverBaseUrl;
  String _serverBaseUrl = _defaultServerBaseUrl;
  String? _sessionToken;
  MuseUser? _currentUser;
  bool _authLoading = false;
  Locale? _locale;

  String get apiBaseUrl => _apiBaseUrl;
  String get resolverBaseUrl => _resolverBaseUrl;
  String get serverBaseUrl => _serverBaseUrl;
  String? get sessionToken => _sessionToken;
  MuseUser? get currentUser => _currentUser;
  bool get isSignedIn => _sessionToken != null && _currentUser != null;
  bool get authLoading => _authLoading;
  Locale? get locale => _locale;
  Set<int> get favoriteIds => Set.unmodifiable(_favoriteIds);
  List<DownloadedSong> get downloads => List.unmodifiable(_downloads.values);
  bool isDownloaded(Song song) => _downloads.containsKey(song.id);
  bool isDownloading(Song song) => _downloadingIds.contains(song.id);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBaseUrl = MusicApi.normalizeBaseUrl(
      prefs.getString(_apiBaseUrlKey) ?? MusicApi.defaultBaseUrl,
    );
    final storedResolver = prefs.getString(_resolverBaseUrlKey);
    _resolverBaseUrl = storedResolver == null || storedResolver.trim().isEmpty
        ? _defaultResolverBaseUrl
        : MusicApi.normalizeOptionalBaseUrl(storedResolver);
    _serverBaseUrl = MusicApi.normalizeBaseUrl(
      prefs.getString(_serverBaseUrlKey) ?? _defaultServerBaseUrl,
    );
    api.baseUrl = _apiBaseUrl;
    api.resolverBaseUrl = _resolverBaseUrl;
    serverApi.baseUrl = _serverBaseUrl;
    _sessionToken = prefs.getString(_sessionTokenKey);
    _locale = _decodeLocale(prefs.getString(_localeKey));
    final storedFavorites = prefs.getStringList(_favoritesKey) ?? const [];
    _favoriteIds
      ..clear()
      ..addAll(storedFavorites
          .map((item) => int.tryParse(item) ?? 0)
          .where((id) => id != 0));
    _favoriteTrackIdsBySongId
      ..clear()
      ..addAll(_decodeFavoriteTrackIds(
          prefs.getStringList(_favoriteTrackIdsKey) ?? const []));
    await _restoreSession();
    await refreshDownloads();
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    final encoded = _encodeLocale(locale);
    if (encoded == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, encoded);
    }
    notifyListeners();
  }

  Future<void> setApiBaseUrl(String value) async {
    final trimmed = MusicApi.normalizeBaseUrl(value);
    if (trimmed.isEmpty) return;
    _apiBaseUrl = trimmed;
    api.baseUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseUrlKey, trimmed);
    notifyListeners();
  }

  Future<void> setResolverBaseUrl(String value) async {
    final trimmed = MusicApi.normalizeOptionalBaseUrl(value);
    _resolverBaseUrl = trimmed;
    api.resolverBaseUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_resolverBaseUrlKey, trimmed);
    notifyListeners();
  }

  Future<void> setServerBaseUrl(String value) async {
    final trimmed = MusicApi.normalizeBaseUrl(value);
    if (trimmed.isEmpty) return;
    _serverBaseUrl = trimmed;
    serverApi.baseUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverBaseUrlKey, trimmed);
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    await _runAuth(() {
      return serverApi.register(
        email: email,
        password: password,
        displayName: displayName,
      );
    });
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    await _runAuth(() {
      return serverApi.login(email: email, password: password);
    });
  }

  Future<void> logout() async {
    final token = _sessionToken;
    _authLoading = true;
    notifyListeners();
    try {
      if (token != null) {
        try {
          await serverApi.logout(token);
        } on Object {
          // Local session cleanup should still succeed when the server is offline.
        }
      }
      await _clearSession();
    } finally {
      _authLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(Song song) async {
    final wasFavorite = _favoriteIds.contains(song.id);
    if (wasFavorite) {
      _favoriteIds.remove(song.id);
    } else {
      _favoriteIds.add(song.id);
    }
    await _persistFavorites();
    notifyListeners();

    final token = _sessionToken;
    if (token == null || token.isEmpty) return;

    try {
      var trackId = _favoriteTrackIdsBySongId[song.id];
      if (trackId == null || trackId.isEmpty) {
        final resolved = await serverApi.resolveSong(token, song);
        trackId = resolved.trackId;
        _favoriteTrackIdsBySongId[song.id] = trackId;
        await _persistFavorites();
      }
      if (wasFavorite) {
        await serverApi.removeFavorite(token, trackId);
        _favoriteTrackIdsBySongId.remove(song.id);
      } else {
        await serverApi.addFavorite(token, trackId);
      }
      await _persistFavorites();
    } on Object {
      if (wasFavorite) {
        _favoriteIds.add(song.id);
      } else {
        _favoriteIds.remove(song.id);
      }
      await _persistFavorites();
      notifyListeners();
    }
  }

  bool isFavorite(Song song) => _favoriteIds.contains(song.id);

  Future<void> refreshDownloads() async {
    final items = await downloadService.listDownloads();
    _downloads
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.song.id, item)));
    notifyListeners();
  }

  Future<void> downloadSong(Song song) async {
    if (_downloads.containsKey(song.id) || _downloadingIds.contains(song.id)) {
      return;
    }
    _downloadingIds.add(song.id);
    notifyListeners();
    try {
      final item = await downloadService.downloadSong(song);
      _downloads[item.song.id] = item;
    } finally {
      _downloadingIds.remove(song.id);
      notifyListeners();
    }
  }

  Future<void> deleteDownload(Song song) async {
    await downloadService.deleteDownload(song.id);
    _downloads.remove(song.id);
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    final token = _sessionToken;
    if (token == null || token.isEmpty) {
      _sessionToken = null;
      _currentUser = null;
      return;
    }
    try {
      _currentUser = await serverApi.me(token);
      try {
        await _syncFavoritesFromServer(token);
      } on Object {
        // Keep the account signed in; favorites can retry on the next launch.
      }
    } on Object {
      await _clearSession();
    }
  }

  Future<void> _runAuth(
    Future<MuseHubAuthResult> Function() action,
  ) async {
    _authLoading = true;
    notifyListeners();
    try {
      final result = await action();
      _sessionToken = result.token;
      _currentUser = result.user;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionTokenKey, result.token);
      try {
        await _syncFavoritesFromServer(result.token, uploadLocalFavorites: true);
      } on Object {
        // Auth should not fail just because sync is temporarily unavailable.
      }
    } finally {
      _authLoading = false;
      notifyListeners();
    }
  }

  Future<void> _clearSession() async {
    _sessionToken = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
  }

  Future<void> _syncFavoritesFromServer(
    String token, {
    bool uploadLocalFavorites = false,
  }) async {
    final localIds = Set<int>.from(_favoriteIds);
    final remoteFavorites = await serverApi.favorites(token);
    final remoteSongIds = <int>{};
    final remoteTrackIdsBySongId = <int, String>{};

    for (final favorite in remoteFavorites) {
      final songId = favorite.neteaseSongId;
      if (songId == null) continue;
      remoteSongIds.add(songId);
      remoteTrackIdsBySongId[songId] = favorite.trackId;
    }

    _favoriteIds
      ..clear()
      ..addAll(remoteSongIds)
      ..addAll(uploadLocalFavorites ? localIds : const <int>{});
    _favoriteTrackIdsBySongId
      ..clear()
      ..addAll(remoteTrackIdsBySongId);
    await _persistFavorites();

    if (!uploadLocalFavorites) return;
    final missingRemoteIds = localIds.difference(remoteSongIds);
    for (final songId in missingRemoteIds) {
      try {
        final details = await api.songDetails([songId]);
        if (details.isEmpty) continue;
        final resolved = await serverApi.resolveSong(token, details.first);
        await serverApi.addFavorite(token, resolved.trackId);
        _favoriteTrackIdsBySongId[songId] = resolved.trackId;
      } on Object {
        // Keep the local favorite; it can be retried on the next login.
      }
    }
    await _persistFavorites();
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _favoritesKey,
      _favoriteIds.map((id) => '$id').toList(),
    );
    await prefs.setStringList(
      _favoriteTrackIdsKey,
      _favoriteTrackIdsBySongId.entries
          .map((entry) => '${entry.key}:${entry.value}')
          .toList(),
    );
  }

  static Map<int, String> _decodeFavoriteTrackIds(List<String> values) {
    final result = <int, String>{};
    for (final value in values) {
      final separator = value.indexOf(':');
      if (separator <= 0 || separator == value.length - 1) continue;
      final songId = int.tryParse(value.substring(0, separator));
      final trackId = value.substring(separator + 1);
      if (songId != null && songId != 0 && trackId.isNotEmpty) {
        result[songId] = trackId;
      }
    }
    return result;
  }

  static String? _encodeLocale(Locale? locale) {
    if (locale == null) return null;
    final scriptCode = locale.scriptCode;
    if (scriptCode == null || scriptCode.isEmpty) {
      return locale.languageCode;
    }
    return '${locale.languageCode}-$scriptCode';
  }

  static Locale? _decodeLocale(String? value) {
    return switch (value) {
      'en' => const Locale('en'),
      'zh-Hans' => const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
      'zh-Hant' => const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
        ),
      _ => null,
    };
  }

  static String localeLabel(BuildContext context, Locale? locale) {
    final strings = AppStrings.of(context);
    return switch (_encodeLocale(locale)) {
      'en' => strings.english,
      'zh-Hans' => strings.simplifiedChinese,
      'zh-Hant' => strings.traditionalChinese,
      _ => strings.followSystem,
    };
  }

  static String get _defaultResolverBaseUrl {
    if (kIsWeb) return MusicApi.defaultResolverBaseUrl;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:30489',
      TargetPlatform.macOS => 'http://127.0.0.1:30489',
      _ => MusicApi.defaultResolverBaseUrl,
    };
  }

  static String get _defaultServerBaseUrl {
    if (kIsWeb) return MuseHubServerApi.defaultBaseUrl;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:30490',
      TargetPlatform.macOS => 'http://127.0.0.1:30490',
      _ => MuseHubServerApi.defaultBaseUrl,
    };
  }
}
