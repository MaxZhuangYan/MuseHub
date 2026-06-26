import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/song.dart';
import 'services/music_api.dart';

class AppState extends ChangeNotifier {
  AppState(this.api);

  final MusicApi api;

  static const _apiBaseUrlKey = 'apiBaseUrl';
  final Set<int> _favoriteIds = {};
  String _apiBaseUrl = MusicApi.defaultBaseUrl;

  String get apiBaseUrl => _apiBaseUrl;
  Set<int> get favoriteIds => Set.unmodifiable(_favoriteIds);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBaseUrl = prefs.getString(_apiBaseUrlKey) ?? MusicApi.defaultBaseUrl;
    api.baseUrl = _apiBaseUrl;
    final storedFavorites = prefs.getStringList('favorites') ?? const [];
    _favoriteIds
      ..clear()
      ..addAll(storedFavorites.map((item) => int.tryParse(item) ?? 0).where((id) => id != 0));
    notifyListeners();
  }

  Future<void> setApiBaseUrl(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    _apiBaseUrl = trimmed;
    api.baseUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseUrlKey, trimmed);
    notifyListeners();
  }

  Future<void> toggleFavorite(Song song) async {
    if (_favoriteIds.contains(song.id)) {
      _favoriteIds.remove(song.id);
    } else {
      _favoriteIds.add(song.id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', _favoriteIds.map((id) => '$id').toList());
    notifyListeners();
  }

  bool isFavorite(Song song) => _favoriteIds.contains(song.id);
}
