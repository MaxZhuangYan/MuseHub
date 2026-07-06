import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_strings.dart';
import 'models/song.dart';
import 'services/music_api.dart';

class AppState extends ChangeNotifier {
  AppState(this.api);

  final MusicApi api;

  static const _apiBaseUrlKey = 'apiBaseUrl';
  static const _resolverBaseUrlKey = 'resolverBaseUrl';
  static const _localeKey = 'locale';
  final Set<int> _favoriteIds = {};
  String _apiBaseUrl = MusicApi.defaultBaseUrl;
  String _resolverBaseUrl = _defaultResolverBaseUrl;
  Locale? _locale;

  String get apiBaseUrl => _apiBaseUrl;
  String get resolverBaseUrl => _resolverBaseUrl;
  Locale? get locale => _locale;
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
    _locale = _decodeLocale(prefs.getString(_localeKey));
    final storedFavorites = prefs.getStringList('favorites') ?? const [];
    _favoriteIds
      ..clear()
      ..addAll(storedFavorites
          .map((item) => int.tryParse(item) ?? 0)
          .where((id) => id != 0));
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
}
