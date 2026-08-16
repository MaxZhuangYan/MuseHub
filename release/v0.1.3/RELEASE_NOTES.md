# MuseHub v0.1.3

## System Media Controls

- Playback is now a real OS media session. Lock screen, notification shade, Control Center, media keys, and headset / bluetooth buttons all control MuseHub, and playback continues in the background.
- Next / previous from the system controls drive MuseHub's own queue, so they behave exactly like the in-app buttons.
- **Android fix:** the media notification never appeared on Android 13+ devices (including HarmonyOS phones), which meant no transport controls at all in the control centre. `POST_NOTIFICATIONS` has been a runtime permission since Android 13 and was never requested; MuseHub now asks for it on first launch. Denying it only costs you the notification controls — playback still works.

## Player

- Added a volume slider to the full player, with a tap-to-mute speaker icon and a 0–100 readout. Volume is remembered across launches.
- Lyrics now scroll to follow playback instead of staying frozen where they were when the sheet opened.

## Playback Stability

- Downloads that are too small to be real audio (error pages, interrupted transfers, preview-length clips) are no longer saved, no longer played from cache, and are swept out at startup along with leftover `.tmp` download fragments. A corrupt cached file no longer wins over streaming the track properly.
- Tightened the app's image cache to a fixed ceiling so memory stays bounded during long listening sessions, and cover-art colour extraction is now cached per cover instead of re-decoding the same artwork on every replay.
- Added diagnostics around playback stalls and source resolution (`MuseHub.Stall`, `MuseHub.Resolve`) to make intermittent stall reports investigable rather than guesswork.

## Notes

- The audio source chain is unchanged from v0.1.2: Netease direct → the built-in pure-Dart fallback → the optional local Alger resolver. A Kuwo fallback was briefly added during this cycle and has been reverted — it only ran when the primary fallback was unavailable, and its title/artist matching was not reliable enough to trust.
- The built-in fallback still depends on GD Studio's public API as a single external point. It had a temporary outage during this cycle; the app has no way to work around that when it happens.

## Artifacts

- `MuseHub-v0.1.3-android-arm64-release.apk`
- `MuseHub-v0.1.3-macos-arm64.zip`
- `MuseHub-v0.1.3-web.zip`
- `MuseHub-v0.1.3-ios-unsigned.zip`
- `SHA256SUMS.txt`
