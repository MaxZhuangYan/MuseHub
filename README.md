# MuseHub

MuseHub is a Flutter mobile rebuild inspired by [AlgerMusicPlayer](https://github.com/algerkong/AlgerMusicPlayer). The desktop app is Electron/Vue; this repo starts a native mobile Flutter implementation with the same core product shape:

- Home discovery with banners, new songs, and recommended playlists
- Netease-compatible search and search suggestions
- Song detail, stream URL, lyric, playlist detail, and album detail API wrappers
- Queue-based playback with `just_audio`
- Mini player, full-screen player, bottom navigation, library favorites, and settings
- Configurable API base URL with direct Netease endpoints and legacy API fallback

## Prerequisites

Install Flutter SDK 3.22 or newer, then run:

```sh
flutter pub get
flutter run
```

On a Mac without a connected phone, run the desktop or web target directly:

```sh
flutter run -d macos
flutter run -d chrome
```

## API Server

The app defaults to `https://music.163.com/api` and falls back to the legacy
Vercel-hosted Netease Cloud Music API for endpoints that still need that
compatibility layer. Open **Settings** in the app to point it at your own API
server if needed. The Flutter code normalizes trailing slashes and the old
`/api.php` suffix, so these forms are accepted:

```txt
https://your-host.example
https://your-host.example/
https://your-host.example/api.php
```

## Alger Fallback Resolver

AlgerMusicPlayer does not rely only on `/song/url/v1`. When the official URL
is empty, it falls back to `@unblockneteasemusic/server` with sources such as
Migu, Kugou, Kuwo, and pyncmd. MuseHub can call the same style of resolver over
HTTP.

Run the local resolver:

```sh
cd tools/alger_resolver
npm install
npm start
```

The resolver listens on `0.0.0.0:30489` by default, so Android emulators and
physical phones on the same Wi-Fi can reach the Mac that runs it.

Then set **Settings -> Alger fallback resolver URL**:

```txt
http://127.0.0.1:30489       # macOS desktop target
http://10.0.2.2:30489        # Android emulator talking to this Mac
http://YOUR_MAC_LAN_IP:30489 # physical phone on the same Wi-Fi
```

Leave the field empty to disable fallback resolving.

## Project Layout

```txt
lib/
  core/        API client, models, theme, and small shared widgets
  features/    Home, search, library, settings, and player screens
  player/      Queue and audio playback controller
  main.dart    App shell and navigation
```
