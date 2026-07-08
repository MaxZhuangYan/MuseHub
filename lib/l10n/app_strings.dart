import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ];

  static const delegate = _AppStringsDelegate();

  static AppStrings of(BuildContext context) {
    return Localizations.of<AppStrings>(context, AppStrings)!;
  }

  bool get _isTraditional {
    final scriptCode = locale.scriptCode?.toLowerCase();
    final countryCode = locale.countryCode?.toLowerCase();
    return scriptCode == 'hant' ||
        countryCode == 'tw' ||
        countryCode == 'hk' ||
        countryCode == 'mo';
  }

  Map<String, String> get _strings {
    if (locale.languageCode == 'zh') {
      return _isTraditional ? _zhHant : _zhHans;
    }
    return _en;
  }

  String _t(String key) => _strings[key] ?? _en[key] ?? key;

  String get appName => _t('appName');
  String get home => _t('home');
  String get search => _t('search');
  String get library => _t('library');
  String get settings => _t('settings');
  String get play => _t('play');
  String get pause => _t('pause');
  String get next => _t('next');
  String get previous => _t('previous');
  String get retry => _t('retry');
  String get save => _t('save');
  String get reset => _t('reset');
  String get favorite => _t('favorite');
  String get removeFavorite => _t('removeFavorite');
  String get moreOptions => _t('moreOptions');
  String get nothingPlaying => _t('nothingPlaying');
  String get nowPlaying => _t('nowPlaying');
  String get repeat => _t('repeat');
  String get queue => _t('queue');
  String get lyrics => _t('lyrics');
  String get lyricsUnavailable => _t('lyricsUnavailable');
  String get trackUnavailable => _t('trackUnavailable');
  String get madeForYou => _t('madeForYou');
  String get playAll => _t('playAll');
  String get newReleases => _t('newReleases');
  String get goodMusic => _t('goodMusic');
  String get trendingNow => _t('trendingNow');
  String get featuredPlaylist => _t('featuredPlaylist');
  String get fallbackBannerTitle => _t('fallbackBannerTitle');
  String get cinematicMix => _t('cinematicMix');
  String get searchHint => _t('searchHint');
  String get searchForMusic => _t('searchForMusic');
  String get searchEmptyBody => _t('searchEmptyBody');
  String get apiBaseUrl => _t('apiBaseUrl');
  String get resolverUrl => _t('resolverUrl');
  String get resolverHelper => _t('resolverHelper');
  String get serverBaseUrl => _t('serverBaseUrl');
  String get serverHelper => _t('serverHelper');
  String get musicServicesUpdated => _t('musicServicesUpdated');
  String get account => _t('account');
  String get signedOut => _t('signedOut');
  String get signIn => _t('signIn');
  String get createAccount => _t('createAccount');
  String get signOut => _t('signOut');
  String get email => _t('email');
  String get password => _t('password');
  String get displayName => _t('displayName');
  String get optional => _t('optional');
  String get authRequired => _t('authRequired');
  String get authSuccess => _t('authSuccess');
  String get signedOutMessage => _t('signedOutMessage');
  String get accountServerHint => _t('accountServerHint');
  String get language => _t('language');
  String get followSystem => _t('followSystem');
  String get simplifiedChinese => _t('simplifiedChinese');
  String get traditionalChinese => _t('traditionalChinese');
  String get english => _t('english');
  String get favoriteSongs => _t('favoriteSongs');
  String savedLocally(int count) =>
      _t('savedLocally').replaceAll('{count}', '$count');
  String get mobileRebuild => _t('mobileRebuild');
  String get mobileRebuildBody => _t('mobileRebuildBody');
  String get yourFavorites => _t('yourFavorites');
  String get favoritesEmpty => _t('favoritesEmpty');
  String get favorites => _t('favorites');
  String get downloads => _t('downloads');
  String downloadedSongs(int count) =>
      _t('downloadedSongs').replaceAll('{count}', '$count');
  String get downloadsEmpty => _t('downloadsEmpty');
  String get download => _t('download');
  String get downloading => _t('downloading');
  String get downloaded => _t('downloaded');
  String get deleteDownload => _t('deleteDownload');
  String get downloadFailed => _t('downloadFailed');
  String get openDownloadFolder => _t('openDownloadFolder');
  String get openDownloadFolderUnavailable =>
      _t('openDownloadFolderUnavailable');
  String get appearance => _t('appearance');
  String get musicServices => _t('musicServices');
  String get noResults => _t('noResults');
  String playCount(num count) {
    if (count >= 100000000) {
      return _t('hundredMillionPlays')
          .replaceAll('{count}', (count / 100000000).toStringAsFixed(1));
    }
    if (count >= 10000) {
      return _t('tenThousandPlays')
          .replaceAll('{count}', (count / 10000).toStringAsFixed(1));
    }
    return _t('plainPlays').replaceAll('{count}', '$count');
  }
}

class _AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const _AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'en' || locale.languageCode == 'zh';

  @override
  Future<AppStrings> load(Locale locale) {
    return SynchronousFuture<AppStrings>(AppStrings(locale));
  }

  @override
  bool shouldReload(_AppStringsDelegate old) => false;
}

const _en = {
  'appName': 'MuseHub',
  'home': 'Home',
  'search': 'Search',
  'library': 'Library',
  'settings': 'Settings',
  'play': 'Play',
  'pause': 'Pause',
  'next': 'Next',
  'previous': 'Previous',
  'retry': 'Retry',
  'save': 'Save',
  'reset': 'Reset',
  'favorite': 'Favorite',
  'removeFavorite': 'Remove favorite',
  'moreOptions': 'More options',
  'nothingPlaying': 'Nothing is playing',
  'nowPlaying': 'NOW PLAYING',
  'repeat': 'Repeat',
  'queue': 'Queue',
  'lyrics': 'Lyrics',
  'lyricsUnavailable': 'Lyrics will appear when available.',
  'trackUnavailable':
      'This track is unavailable from the current music source.',
  'madeForYou': 'Made For You',
  'playAll': 'Play All',
  'newReleases': 'New Releases',
  'goodMusic': 'Good music,',
  'trendingNow': 'Trending Now',
  'featuredPlaylist': 'FEATURED PLAYLIST',
  'fallbackBannerTitle': 'Neon Nights Vol. 4',
  'cinematicMix': 'A cinematic mix for late night listening.',
  'searchHint': 'Songs, artists, albums...',
  'searchForMusic': 'Search for music',
  'searchEmptyBody': 'Find songs, artists, and albums to build your queue.',
  'apiBaseUrl': 'API base URL',
  'resolverUrl': 'Alger fallback resolver URL',
  'resolverHelper': 'Optional. Example: http://127.0.0.1:30489',
  'serverBaseUrl': 'MuseHub Server URL',
  'serverHelper': 'Example: http://127.0.0.1:30490',
  'musicServicesUpdated': 'Music services updated',
  'account': 'Account',
  'signedOut': 'Not signed in',
  'signIn': 'Sign in',
  'createAccount': 'Create account',
  'signOut': 'Sign out',
  'email': 'Email',
  'password': 'Password',
  'displayName': 'Display name',
  'optional': 'Optional',
  'authRequired': 'Sign in to sync favorites, playlists, and playback state.',
  'authSuccess': 'Account connected',
  'signedOutMessage': 'Signed out',
  'accountServerHint': 'Uses MuseHub Server for account and sync.',
  'language': 'Language',
  'followSystem': 'Follow system',
  'simplifiedChinese': 'Simplified Chinese',
  'traditionalChinese': 'Traditional Chinese',
  'english': 'English',
  'favoriteSongs': 'Favorite songs',
  'savedLocally': '{count} favorites',
  'mobileRebuild': 'Mobile rebuild',
  'mobileRebuildBody': 'A cross-platform MuseHub music client built with Flutter',
  'yourFavorites': 'Your favorites',
  'favoritesEmpty':
      'Favorite songs from Home, Search, or the player will appear here.',
  'favorites': 'Favorites',
  'downloads': 'Downloads',
  'downloadedSongs': '{count} downloaded',
  'downloadsEmpty': 'Downloaded songs will appear here for offline playback.',
  'download': 'Download',
  'downloading': 'Downloading...',
  'downloaded': 'Downloaded',
  'deleteDownload': 'Delete download',
  'downloadFailed': 'Download failed',
  'openDownloadFolder': 'Open download folder',
  'openDownloadFolderUnavailable':
      'Opening the download folder is not available on this platform.',
  'hundredMillionPlays': '{count}B plays',
  'tenThousandPlays': '{count}W plays',
  'plainPlays': '{count} plays',
  'appearance': 'Appearance',
  'musicServices': 'Music Services',
  'noResults': 'No results found',
};

const _zhHans = {
  'appName': 'MuseHub',
  'home': '首页',
  'search': '搜索',
  'library': '资料库',
  'settings': '设置',
  'play': '播放',
  'pause': '暂停',
  'next': '下一首',
  'previous': '上一首',
  'retry': '重试',
  'save': '保存',
  'reset': '重置',
  'favorite': '收藏',
  'removeFavorite': '取消收藏',
  'moreOptions': '更多选项',
  'nothingPlaying': '当前没有播放内容',
  'nowPlaying': '正在播放',
  'repeat': '循环',
  'queue': '播放队列',
  'lyrics': '歌词',
  'lyricsUnavailable': '有可用歌词时会显示在这里。',
  'trackUnavailable': '当前音乐源暂时无法播放这首歌。',
  'madeForYou': '为你推荐',
  'playAll': '全部播放',
  'newReleases': '新歌速递',
  'goodMusic': '好音乐，',
  'trendingNow': '正在流行',
  'featuredPlaylist': '精选歌单',
  'fallbackBannerTitle': '霓虹夜色 Vol. 4',
  'cinematicMix': '适合深夜聆听的电影感歌单。',
  'searchHint': '歌曲、艺人、专辑...',
  'searchForMusic': '搜索音乐',
  'searchEmptyBody': '查找歌曲、艺人和专辑，加入你的播放队列。',
  'apiBaseUrl': 'API 服务地址',
  'resolverUrl': 'Alger 备用解析服务地址',
  'resolverHelper': '可选。例如：http://127.0.0.1:30489',
  'serverBaseUrl': 'MuseHub Server 地址',
  'serverHelper': '例如：http://127.0.0.1:30490',
  'musicServicesUpdated': '音乐服务已更新',
  'account': '账号',
  'signedOut': '未登录',
  'signIn': '登录',
  'createAccount': '注册账号',
  'signOut': '退出登录',
  'email': '邮箱',
  'password': '密码',
  'displayName': '显示名称',
  'optional': '可选',
  'authRequired': '登录后可同步收藏、歌单和播放状态。',
  'authSuccess': '账号已连接',
  'signedOutMessage': '已退出登录',
  'accountServerHint': '使用 MuseHub Server 处理账号与同步。',
  'language': '语言',
  'followSystem': '跟随系统',
  'simplifiedChinese': '简体中文',
  'traditionalChinese': '繁體中文',
  'english': 'English',
  'favoriteSongs': '收藏歌曲',
  'savedLocally': '已收藏 {count} 首',
  'mobileRebuild': '移动版重构',
  'mobileRebuildBody': '基于 Flutter 构建的 MuseHub 跨平台音乐客户端',
  'yourFavorites': '你的收藏',
  'favoritesEmpty': '在首页、搜索或播放器里收藏的歌曲会显示在这里。',
  'favorites': '收藏',
  'downloads': '下载',
  'downloadedSongs': '已下载 {count} 首',
  'downloadsEmpty': '下载的歌曲会显示在这里，可离线播放。',
  'download': '下载',
  'downloading': '下载中...',
  'downloaded': '已下载',
  'deleteDownload': '删除下载',
  'downloadFailed': '下载失败',
  'openDownloadFolder': '打开下载目录',
  'openDownloadFolderUnavailable': '当前平台不支持直接打开下载目录。',
  'hundredMillionPlays': '{count} 亿次播放',
  'tenThousandPlays': '{count} 万次播放',
  'plainPlays': '{count} 次播放',
  'appearance': '外观',
  'musicServices': '音乐服务',
  'noResults': '未找到结果',
};

const _zhHant = {
  'appName': 'MuseHub',
  'home': '首頁',
  'search': '搜尋',
  'library': '資料庫',
  'settings': '設定',
  'play': '播放',
  'pause': '暫停',
  'next': '下一首',
  'previous': '上一首',
  'retry': '重試',
  'save': '儲存',
  'reset': '重設',
  'favorite': '收藏',
  'removeFavorite': '取消收藏',
  'moreOptions': '更多選項',
  'nothingPlaying': '目前沒有播放內容',
  'nowPlaying': '正在播放',
  'repeat': '循環',
  'queue': '播放佇列',
  'lyrics': '歌詞',
  'lyricsUnavailable': '有可用歌詞時會顯示在這裡。',
  'trackUnavailable': '目前音樂來源暫時無法播放這首歌。',
  'madeForYou': '為你推薦',
  'playAll': '全部播放',
  'newReleases': '新歌速遞',
  'goodMusic': '好音樂，',
  'trendingNow': '正在流行',
  'featuredPlaylist': '精選歌單',
  'fallbackBannerTitle': '霓虹夜色 Vol. 4',
  'cinematicMix': '適合深夜聆聽的電影感歌單。',
  'searchHint': '歌曲、藝人、專輯...',
  'searchForMusic': '搜尋音樂',
  'searchEmptyBody': '查找歌曲、藝人和專輯，加入你的播放佇列。',
  'apiBaseUrl': 'API 服務位址',
  'resolverUrl': 'Alger 備用解析服務位址',
  'resolverHelper': '可選。例如：http://127.0.0.1:30489',
  'serverBaseUrl': 'MuseHub Server 位址',
  'serverHelper': '例如：http://127.0.0.1:30490',
  'musicServicesUpdated': '音樂服務已更新',
  'account': '帳號',
  'signedOut': '未登入',
  'signIn': '登入',
  'createAccount': '註冊帳號',
  'signOut': '登出',
  'email': '信箱',
  'password': '密碼',
  'displayName': '顯示名稱',
  'optional': '可選',
  'authRequired': '登入後可同步收藏、歌單和播放狀態。',
  'authSuccess': '帳號已連接',
  'signedOutMessage': '已登出',
  'accountServerHint': '使用 MuseHub Server 處理帳號與同步。',
  'language': '語言',
  'followSystem': '跟隨系統',
  'simplifiedChinese': '简体中文',
  'traditionalChinese': '繁體中文',
  'english': 'English',
  'favoriteSongs': '收藏歌曲',
  'savedLocally': '已收藏 {count} 首',
  'mobileRebuild': '行動版重構',
  'mobileRebuildBody': '基於 Flutter 構建的 MuseHub 跨平台音樂客戶端',
  'yourFavorites': '你的收藏',
  'favoritesEmpty': '在首頁、搜尋或播放器裡收藏的歌曲會顯示在這裡。',
  'favorites': '收藏',
  'downloads': '下載',
  'downloadedSongs': '已下載 {count} 首',
  'downloadsEmpty': '下載的歌曲會顯示在這裡，可離線播放。',
  'download': '下載',
  'downloading': '下載中...',
  'downloaded': '已下載',
  'deleteDownload': '刪除下載',
  'downloadFailed': '下載失敗',
  'openDownloadFolder': '開啟下載目錄',
  'openDownloadFolderUnavailable': '目前平台不支援直接開啟下載目錄。',
  'hundredMillionPlays': '{count} 億次播放',
  'tenThousandPlays': '{count} 萬次播放',
  'plainPlays': '{count} 次播放',
  'appearance': '外觀',
  'musicServices': '音樂服務',
  'noResults': '未找到結果',
};
