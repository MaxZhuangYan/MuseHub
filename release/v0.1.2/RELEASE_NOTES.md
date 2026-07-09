# MuseHub v0.1.2

## Core: Restricted Tracks Work Out of the Box

- Built-in fallback resolution for some VIP / region-restricted Netease tracks. The app now includes a pure-Dart GD Studio / pyncmd-style fallback path, so normal installs no longer require manually starting `tools/alger_resolver`.
- Free tracks still prefer the normal Netease direct/compatible playback path.
- The local Alger resolver remains available as an optional advanced fallback. If you run it yourself, it can add extra independent sources such as Kugou, Kuwo, Migu, QQ, and Bilibili.

## Playback Stability

- Fixed queue auto-advance / repeat cases where a completed track could stay at the end instead of moving to the next song.
- Added a position-based end-of-track fallback for streams that stop emitting reliable `completed` state near the last few seconds.
- Automatically skips unplayable tracks during autoplay so a queue or favorites list is not blocked by one bad source.
- Fixed an Android playback crash by avoiding just_audio's local request-header proxy path in builds where that proxy can initialize incorrectly.

## Notes

- VIP / restricted-track failure messages are more accurate and no longer point users toward starting a resolver as the only path.
- Resolver failure cooldown is shorter, so one network hiccup does not disable fallback playback for minutes.
- The built-in fallback currently depends on GD Studio's public Netease-compatible API. It is smoother than requiring a local resolver, but it is still an external single point; future releases can add more app-side mirrors.

## Artifacts

- `MuseHub-v0.1.2-android-arm64-release.apk`
- `MuseHub-v0.1.2-macos-arm64.zip`
- `MuseHub-v0.1.2-web.zip`
- `MuseHub-v0.1.2-ios-unsigned.zip`
- `SHA256SUMS.txt`
