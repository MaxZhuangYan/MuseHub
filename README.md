# MuseHub

[简体中文](README.zh-CN.md)

MuseHub is a Flutter music client and self-hosted music orchestration stack
inspired by [AlgerMusicPlayer](https://github.com/algerkong/AlgerMusicPlayer).

The current `v0.1.2` release includes a Flutter app, a Node.js/SQLite backend,
account login, favorite sync, local music source support, Netease-compatible
search/playback, built-in restricted-track fallback resolution, and an optional
Alger/unblock advanced resolver.

## Download

Latest release:

[MuseHub v0.1.2](https://github.com/MaxZhuangYan/MuseHub/releases/tag/v0.1.2)

Release artifacts:

- Android: `MuseHub-v0.1.2-android-arm64-release.apk`
- macOS: `MuseHub-v0.1.2-macos-arm64.zip`
- Web: `MuseHub-v0.1.2-web.zip`
- iOS: `MuseHub-v0.1.2-ios-unsigned.zip`

Notes:

- The Android APK is release-built but not signed with a production keystore.
- The iOS artifact is an unsigned `Runner.app` zip. It proves the release build
  passes, but it cannot be installed directly like an APK. Sign it in Xcode, or
  create an Archive for TestFlight, Ad Hoc, or App Store distribution.
- Windows builds must be produced on a Windows machine or CI runner.

For local iPhone testing, open `ios/Runner.xcworkspace` in Xcode, select your
Apple development team, connect an iPhone, and run/sign from Xcode.

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
- Built-in fallback resolution for some VIP/region-restricted Netease tracks
- Optional Alger/unblock advanced resolver with extra sources
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
release/v0.1.2/         Packaged release artifacts
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

MuseHub v0.1.2 has an in-app fallback path for many restricted Netease tracks,
so a packaged app does not require a local resolver for normal playback. The
Alger-style resolver is now an optional advanced fallback that can add more
independent sources such as Kugou, Kuwo, Migu, QQ, and Bilibili when you run it
yourself.

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

Leave the resolver setting empty to use only the built-in app-side paths.

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

`v0.1.2` focuses on making restricted-track playback usable out of the box and
hardening queue playback. The app now includes a pure-Dart fallback resolver for
some VIP/region-restricted Netease tracks, keeps free tracks on the normal
direct/compatible path, and leaves the local Alger resolver as an optional
advanced fallback rather than a required companion process.

Playback stability improvements include more reliable auto-advance at track end,
coverage for the last few seconds where some streams stop emitting clean
completion signals, automatic skip-over for unplayable queued tracks, and an
Android fix for just_audio's local header proxy crash in some builds.

The built-in fallback currently depends on GD Studio's public Netease-compatible
API, the same pyncmd-style source used by popular unblock projects. It is much
smoother than requiring users to run a local resolver, but it is still an
external single point; future releases can add more app-side mirrors.

It is usable for local testing and server-backed favorite sync, but production
distribution still needs:

- Android production signing configuration
- iOS Apple signing and provisioning
- Windows packaging on Windows
- More complete playlist/history sync in the Flutter client
