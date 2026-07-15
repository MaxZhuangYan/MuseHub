import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

/// Bridges the OS media session — lock screen / notification / Control
/// Center / media keys / headset & bluetooth buttons — to
/// [PlayerController]'s custom queue.
///
/// just_audio_background can't drive next/previous here because it derives
/// "has next" from just_audio's own single-item audio source, not our
/// queue. Using audio_service directly lets us forward the system's
/// skip-to-next/previous straight to the controller and publish our own
/// playback state (which is what makes the system buttons appear and work).
class MuseAudioHandler extends BaseAudioHandler {
  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onNext;
  VoidCallback? onPrevious;
  VoidCallback? onStop;
  ValueChanged<Duration>? onSeek;

  @override
  Future<void> play() async => onPlay?.call();

  @override
  Future<void> pause() async => onPause?.call();

  @override
  Future<void> skipToNext() async => onNext?.call();

  @override
  Future<void> skipToPrevious() async => onPrevious?.call();

  @override
  Future<void> stop() async => onStop?.call();

  @override
  Future<void> seek(Duration position) async => onSeek?.call(position);

  void publishMediaItem(MediaItem? item) => mediaItem.add(item);

  void publishPlaybackState(PlaybackState state) => playbackState.add(state);
}
