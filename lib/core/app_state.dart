import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/song.dart';
import 'services/music_api.dart';

class AppState extends ChangeNotifier {
  AppState(this.api);

  final MusicApi api;

  static const _apiBaseUrlKey = 'apiBaseUrl';
  static const _resolverBaseUrlKey = 'resolverBaseUrl';
  final Set<int> _favoriteIds = {};
  String _apiBaseUrl = MusicApi.defaultBaseUrl;
  String _resolverBaseUrl = _defaultResolverBaseUrl;

  String get apiBaseUrl => _apiBaseUrl;
  String get resolverBaseUrl => _resolverBaseUrl;
  Set<int> get favoriteIds => Set.unmodifiable(_favoriteIds);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBaseUrl = MusicApi.normalizeBaseUrl(
      prefs.getString(_apiBaseUrlKey) ?? MusicApi.defaultBaseUrl,
    );
    final storedResolver = prefs.getString(_resolverBaseUrlKey);
    _resolverBaseUrl = storedResolver == null || storedResolver.trim().isEmpty
        ? _defaultResolverBaseUrl
        : MusicApi.normalizeOptionalBaseUrl(storedResolver);
    api.baseUrl = _apiBaseUrl;
    api.resolverBaseUrl = _resolverBaseUrl;
    final storedFavorites = prefs.getStringList('favorites') ?? const [];
    _favoriteIds
      ..clear()
      ..addAll(storedFavorites
          .map((item) => int.tryParse(item) ?? 0)
          .where((id) => id != 0));
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

  Future<void> toggleFavorite(Song song) async {
    if (_favoriteIds.contains(song.id)) {
      _favoriteIds.remove(song.id);
    } else {
      _favoriteIds.add(song.id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'favorites', _favoriteIds.map((id) => '$id').toList());
    notifyListeners();
  }

  bool isFavorite(Song song) => _favoriteIds.contains(song.id);

  static String get _defaultResolverBaseUrl {
    if (kIsWeb) return MusicApi.defaultResolverBaseUrl;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:30489',
      TargetPlatform.macOS => 'http://127.0.0.1:30489',
      _ => MusicApi.defaultResolverBaseUrl,
    };
  }
}
