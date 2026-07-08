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
  }

  final MusicApi _api;
  final DownloadService _downloads;
  final AudioPlayer _audio = AudioPlayer();
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<PlayerState> _stateSub;

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
      var sourceLoaded = false;
      final localPath = await _localPathForSong(hydratedSong.id);
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
      if (!sourceLoaded) {
        final url = await _api.songUrl(hydratedSong);
        if (!_isCurrentRequest(requestId, song.id)) return;
        if (url == null) {
          throw const MusicApiException(
            'This track is unavailable from the current music source.',
          );
        }
        await _audio.setUrl(url).timeout(const Duration(seconds: 12));
      }
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
    _audio.dispose();
    super.dispose();
  }
}
