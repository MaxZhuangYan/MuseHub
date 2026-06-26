# MuseHub

MuseHub is a Flutter mobile rebuild inspired by [AlgerMusicPlayer](https://github.com/algerkong/AlgerMusicPlayer). The desktop app is Electron/Vue; this repo starts a native mobile Flutter implementation with the same core product shape:

- Home discovery with banners, new songs, and recommended playlists
- Netease-compatible search and search suggestions
- Song detail, stream URL, lyric, playlist detail, and album detail API wrappers
- Queue-based playback with `just_audio`
- Mini player, full-screen player, bottom navigation, library favorites, and settings
- Configurable API base URL for self-hosted Netease Cloud Music API-compatible services

## Prerequisites

Install Flutter SDK 3.22 or newer, then run:

```sh
flutter pub get
flutter run
```

## API Server

The app defaults to `https://music-api.gdstudio.xyz/api.php`. Open **Settings** in the app to point it at your own Netease Cloud Music API-compatible server. The Flutter code normalizes trailing slashes, so both of these forms are accepted:

```txt
https://your-host.example
https://your-host.example/
```

## Project Layout

```txt
lib/
  core/        API client, models, theme, and small shared widgets
  features/    Home, search, library, settings, and player screens
  player/      Queue and audio playback controller
  main.dart    App shell and navigation
```
