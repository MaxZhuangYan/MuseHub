import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';

import '../core/models/lyric_line.dart';
import '../core/models/song.dart';
import '../core/services/download_service.dart';
import '../core/services/music_api.dart';

enum PlaybackRepeatMode { off, one, all }

class PlayerController extends ChangeNotifier {
  PlayerController(this._api, this._downloads) {
    _positionSub = _audio.positionStream.listen((value) {
      _position = value;
      notifyListeners();
    });
    _durationSub = _audio.durationStream.listen((value) {
      _duration = value ?? Duration.zero;
      notifyListeners();
    });
    _stateSub = _audio.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      if (!_isLoading && state.processingState == ProcessingState.completed) {
        unawaited(next(automatic: true));
      }
      notifyListeners();
    });
    _stallWatchdog = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _checkPlaybackStall(),
    );
  }

  final MusicApi _api;
  final DownloadService _downloads;
  final AudioPlayer _audio = AudioPlayer();
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<PlayerState> _stateSub;
  late final Timer _stallWatchdog;

  List<Song> _queue = [];
  Song? _current;
  List<LyricLine> _lyrics = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _isLoading = false;
  String? _error;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.all;
  int _playRequestId = 0;
  Duration? _lastWatchdogPosition;
  int _stalledTicks = 0;
  bool _recoveringStall = false;

  // Ambient color extracted from current song cover art
  Color? _ambientColor;
  int _colorRequestId = 0;

  List<Song> get queue => List.unmodifiable(_queue);
  Song? get current => _current;
  List<LyricLine> get lyrics => List.unmodifiable(_lyrics);
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PlaybackRepeatMode get repeatMode => _repeatMode;

  /// Dominant/vibrant color from the currently playing song's cover art.
  Color? get ambientColor => _ambientColor;

  LyricLine? get activeLyric {
    if (_lyrics.isEmpty) return null;
    LyricLine? active = _lyrics.first;
    for (final line in _lyrics) {
      if (line.time <= _position) active = line;
    }
    return active;
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    final requestId = ++_playRequestId;
    if (queue != null && queue.isNotEmpty) {
      _queue = queue;
    } else if (!_queue.any((item) => item.id == song.id)) {
      _queue = [..._queue, song];
    }

    _current = song;
    _lyrics = [];
    _position = Duration.zero;
    _duration = song.durationMs == null
        ? Duration.zero
        : Duration(milliseconds: song.durationMs!);
    _isPlaying = false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Kick off palette extraction in parallel; result notifies independently
    unawaited(_extractAmbientColor(song.coverUrl));

    try {
      await _audio.stop();
      if (!_isCurrentRequest(requestId, song.id)) return;
      final hydratedSong = await _hydrateSongForPlayback(song);
      if (!_isCurrentRequest(requestId, song.id)) return;
      if (!identical(hydratedSong, song)) {
        _current = hydratedSong;
        _queue = [
          for (final item in _queue)
            item.id == hydratedSong.id ? item.mergeDetails(hydratedSong) : item,
        ];
        _duration = hydratedSong.durationMs == null
            ? _duration
            : Duration(milliseconds: hydratedSong.durationMs!);
        notifyListeners();
      }
      unawaited(_loadLyrics(song.id, requestId));
      await _loadAudioSource(hydratedSong, requestId);
      if (!_isCurrentRequest(requestId, song.id)) return;
      await _audio.play();
    } catch (error) {
      if (!_isCurrentRequest(requestId, song.id)) return;
      await _audio.stop();
      if (!_isCurrentRequest(requestId, song.id)) return;
      _position = Duration.zero;
      _isPlaying = false;
      _error = error.toString();
    } finally {
      if (_isCurrentRequest(requestId, song.id)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadAudioSource(Song song, int requestId) async {
    var sourceLoaded = false;
    final localPath = await _localPathForSong(song.id);
    if (!_isCurrentRequest(requestId, song.id)) return;
    if (localPath != null) {
      try {
        await _audio
            .setFilePath(localPath)
            .timeout(const Duration(seconds: 12));
        sourceLoaded = true;
      } on Object {
        sourceLoaded = false;
      }
    }
    if (sourceLoaded) return;

    final url = await _api.songUrl(song);
    if (!_isCurrentRequest(requestId, song.id)) return;
    if (url == null) {
      throw const MusicApiException(
        'This track is unavailable from the current music source.',
      );
    }
    await _audio.setUrl(url).timeout(const Duration(seconds: 12));
  }

  Future<String?> _localPathForSong(int songId) async {
    try {
      return await _downloads.localPathForSong(songId);
    } on Object {
      return null;
    }
  }

  Future<void> toggle() async {
    if (_current == null) return;
    if (_isLoading && !_audio.playing) return;
    if (_error != null) {
      final song = _current!;
      await playSong(song, queue: _queue);
      return;
    }
    if (_audio.playing) {
      await _audio.pause();
    } else {
      await _audio.play();
    }
  }

  Future<void> seek(Duration position) => _audio.seek(position);

  Future<Song> _hydrateSongForPlayback(Song song) async {
    if (song.coverUrl.isNotEmpty && song.artists.isNotEmpty) return song;
    try {
      final details = await _api.songDetails([song.id]);
      if (details.isEmpty) return song;
      return song.mergeDetails(details.first);
    } catch (_) {
      return song;
    }
  }

  Future<void> _loadLyrics(int songId, int requestId) async {
    try {
      final lyrics = await _api.lyrics(songId);
      if (!_isCurrentRequest(requestId, songId)) return;
      _lyrics = lyrics;
      notifyListeners();
    } catch (_) {
      // Lyrics are optional and should not interrupt playback.
    }
  }

  bool _isCurrentRequest(int requestId, int songId) =>
      requestId == _playRequestId && _current?.id == songId;

  void _checkPlaybackStall() {
    if (_current == null ||
        !_audio.playing ||
        _isLoading ||
        _error != null ||
        _recoveringStall) {
      _resetStallWatchdog();
      return;
    }
    if (_audio.processingState == ProcessingState.completed ||
        _audio.processingState == ProcessingState.idle) {
      _resetStallWatchdog();
      return;
    }
    if (_duration > Duration.zero &&
        _position >= _duration - const Duration(seconds: 3)) {
      _resetStallWatchdog();
      return;
    }

    final last = _lastWatchdogPosition;
    _lastWatchdogPosition = _position;
    if (last == null) return;

    final delta = (_position - last).abs();
    if (delta > const Duration(milliseconds: 600)) {
      _stalledTicks = 0;
      return;
    }

    _stalledTicks += 1;
    if (_stalledTicks >= 3) {
      _stalledTicks = 0;
      unawaited(_recoverStalledPlayback());
    }
  }

  void _resetStallWatchdog() {
    _lastWatchdogPosition = null;
    _stalledTicks = 0;
  }

  Future<void> _recoverStalledPlayback() async {
    final song = _current;
    if (song == null || _recoveringStall) return;
    final requestId = _playRequestId;
    final resumeAt = _position;
    _recoveringStall = true;
    _isLoading = true;
    notifyListeners();

    try {
      await _audio.stop();
      if (!_isCurrentRequest(requestId, song.id)) return;
      await _loadAudioSource(song, requestId);
      if (!_isCurrentRequest(requestId, song.id)) return;
      if (resumeAt > Duration.zero) {
        await _audio.seek(resumeAt);
      }
      if (!_isCurrentRequest(requestId, song.id)) return;
      await _audio.play();
    } catch (error) {
      if (!_isCurrentRequest(requestId, song.id)) return;
      _isPlaying = false;
      _error = error.toString();
    } finally {
      _recoveringStall = false;
      _resetStallWatchdog();
      if (_isCurrentRequest(requestId, song.id)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _extractAmbientColor(String coverUrl) async {
    if (coverUrl.isEmpty) return;
    final reqId = ++_colorRequestId;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(coverUrl),
        size: const Size(60, 60),
        maximumColorCount: 12,
      );
      if (reqId != _colorRequestId) return;
      final color = palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.dominantColor?.color;
      if (color != null) {
        _ambientColor = color;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> next({bool automatic = false}) async {
    final song = _nextSong(respectRepeatOne: automatic);
    if (song != null) await playSong(song);
  }

  Future<void> previous() async {
    final song = _previousSong();
    if (song != null) await playSong(song);
  }

  void cycleRepeatMode() {
    _repeatMode = switch (_repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.off,
    };
    notifyListeners();
  }

  Song? _nextSong({bool respectRepeatOne = false}) {
    if (_current == null || _queue.isEmpty) return _current;
    if (respectRepeatOne && _repeatMode == PlaybackRepeatMode.one) {
      return _current;
    }
    final index = _queue.indexWhere((song) => song.id == _current!.id);
    if (index == -1) return _queue.first;
    if (index + 1 < _queue.length) return _queue[index + 1];
    if (_repeatMode != PlaybackRepeatMode.all) return null;
    return _queue.first;
  }

  Song? _previousSong() {
    if (_current == null || _queue.isEmpty) return _current;
    final index = _queue.indexWhere((song) => song.id == _current!.id);
    if (index == -1) return _queue.last;
    if (index > 0) return _queue[index - 1];
    if (_repeatMode != PlaybackRepeatMode.all) return null;
    return _queue.last;
  }

  @override
  void dispose() {
    _positionSub.cancel();
    _durationSub.cancel();
    _stateSub.cancel();
    _stallWatchdog.cancel();
    _audio.dispose();
    super.dispose();
  }
}
