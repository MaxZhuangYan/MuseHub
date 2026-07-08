# MuseHub

MuseHub is a Flutter music client and self-hosted music orchestration stack
inspired by [AlgerMusicPlayer](https://github.com/algerkong/AlgerMusicPlayer).

The current `v0.1.0` release includes a Flutter app, a Node.js/SQLite backend,
account login, favorite sync, local music source support, Netease-compatible
search/playback, and optional Alger/unblock resolver fallback.

## Download

Latest release:

[MuseHub v0.1.0](https://github.com/MaxZhuangYan/MuseHub/releases/tag/v0.1.0)

Release artifacts:

- Android: `MuseHub-v0.1.0-android-arm64-release.apk`
- macOS: `MuseHub-v0.1.0-macos-arm64.zip`
- Web: `MuseHub-v0.1.0-web.zip`
- iOS: `MuseHub-v0.1.0-ios-unsigned.zip`

Notes:

- The Android APK is release-built but not signed with a production keystore.
- The iOS build is unsigned and must be signed in Xcode before device install.
- Windows builds must be produced on a Windows machine or CI runner.

## Server Setup

The app can use a MuseHub Server for account and sync. In app settings, point
the client at your own server:

```txt
MuseHub Server: https://your-musehub-server.example
Alger Resolver: leave empty unless you run one yourself
```

For a phone or emulator, do not use `127.0.0.1` unless the server is running
inside that same device. Use your server IP or LAN IP instead.

## Features

- Home discovery, search, library, settings, mini player, and full player
- Queue playback using `just_audio`
- Netease direct/compatible API support
- Optional Alger/unblock fallback resolver
- MuseHub Server account registration and login
- Favorite sync across devices for the same account
- Server-side track identity, source bindings, playlist, favorite, playback
  state, and history APIs
- Local music folder source on the server
- Server-side stream proxy with Range request support

## Project Structure

```txt
lib/
  core/                 Flutter app state, API clients, models, theme, widgets
  features/             Home, search, library, settings, player screens
  player/               Queue and playback controller
  main.dart             Flutter app entry point

musehub-server/
  src/                  Hono + SQLite backend
  scripts/              Smoke tests and sample data helper

tools/alger_resolver/   Optional unblock resolver wrapper
release/v0.1.0/         Packaged release artifacts
```

## Run Flutter App

Install Flutter 3.44 or newer, then:

```sh
flutter pub get
flutter run
```

Useful local targets:

```sh
flutter run -d macos
flutter run -d chrome
flutter run -d android
```

## Run MuseHub Server

```sh
cd musehub-server
npm install
npm run dev
```

Defaults:

- HTTP: `http://127.0.0.1:30490`
- SQLite: `./data/musehub.sqlite`
- Local music folder: `/music`

Example with local music:

```sh
cd musehub-server
npm run sample:local
MUSIC_DIR=./music npm run dev
```

More backend details are in [musehub-server/README.md](musehub-server/README.md).

## Optional Alger Resolver

MuseHub can call an Alger-style unblock resolver when the primary source cannot
produce a playable URL.

```sh
cd tools/alger_resolver
npm install
npm start
```

Default resolver URL:

```txt
http://127.0.0.1:30489
```

Use platform-specific addresses in the app:

```txt
macOS desktop target:      http://127.0.0.1:30489
Android emulator:         http://10.0.2.2:30489
Physical phone on Wi-Fi:  http://YOUR_MAC_LAN_IP:30489
```

Leave the resolver setting empty to disable it.

## Build

```sh
flutter analyze
flutter test

flutter build apk --release
flutter build macos --release
flutter build web --release
flutter build ios --release --no-codesign
```

Backend validation:

```sh
cd musehub-server
npm run typecheck
npm run build
npm run smoke
```

## Release Notes

`v0.1.0` is a preview release. It is usable for local testing and server-backed
favorite sync, but production distribution still needs:

- Android production signing configuration
- iOS Apple signing and provisioning
- Windows packaging on Windows
- More complete playlist/history sync in the Flutter client
