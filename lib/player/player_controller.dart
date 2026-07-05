import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/models/lyric_line.dart';
import '../core/models/song.dart';
import '../core/services/music_api.dart';

enum PlaybackRepeatMode { off, one, all }

class PlayerController extends ChangeNotifier {
  PlayerController(this._api) {
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
      if (state.processingState == ProcessingState.completed) {
        next();
      }
      notifyListeners();
    });
  }

  final MusicApi _api;
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
  final Set<int> _unplayableIds = {};

  List<Song> get queue => List.unmodifiable(_queue);
  Song? get current => _current;
  List<LyricLine> get lyrics => List.unmodifiable(_lyrics);
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get error => _error;
  PlaybackRepeatMode get repeatMode => _repeatMode;

  LyricLine? get activeLyric {
    if (_lyrics.isEmpty) return null;
    LyricLine? active = _lyrics.first;
    for (final line in _lyrics) {
      if (line.time <= _position) active = line;
    }
    return active;
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
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

    try {
      await _audio.stop();
      _loadLyrics(song.id);
      final url = await _api.songUrl(song);
      if (url == null) {
        throw const MusicApiException(
          'This track is unavailable from the current music source.',
        );
      }
      await _audio.setUrl(url).timeout(const Duration(seconds: 12));
      await _audio.play();
    } catch (error) {
      await _audio.stop();
      _position = Duration.zero;
      _isPlaying = false;
      _error = error.toString();
      _unplayableIds.add(song.id);
      if (_queue.length > 1) {
        Future<void>.delayed(const Duration(milliseconds: 900), () {
          if (_current?.id == song.id && _error != null) next();
        });
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (_current == null) return;
    if (_error != null) {
      final song = _current!;
      _unplayableIds.remove(song.id);
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

  Future<void> _loadLyrics(int songId) async {
    try {
      _lyrics = await _api.lyrics(songId);
      notifyListeners();
    } catch (_) {
      // Lyrics are optional and should not interrupt playback.
    }
  }

  Future<void> next() async {
    final song = _nextSong(skipUnplayable: true);
    if (song != null) await playSong(song);
  }

  Future<void> previous() async {
    final song = _previousSong(skipUnplayable: true);
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

  Song? _nextSong({bool skipUnplayable = false}) {
    if (_current == null || _queue.isEmpty) return _current;
    if (_repeatMode == PlaybackRepeatMode.one &&
        (!skipUnplayable || !_unplayableIds.contains(_current!.id))) {
      return _current;
    }
    final index = _queue.indexWhere((song) => song.id == _current!.id);
    if (index == -1) return _queue.first;
    for (var i = index + 1; i < _queue.length; i++) {
      if (!skipUnplayable || !_unplayableIds.contains(_queue[i].id)) {
        return _queue[i];
      }
    }
    if (_repeatMode != PlaybackRepeatMode.all) return null;
    for (var i = 0; i <= index; i++) {
      if (!skipUnplayable || !_unplayableIds.contains(_queue[i].id)) {
        return _queue[i];
      }
    }
    return null;
  }

  Song? _previousSong({bool skipUnplayable = false}) {
    if (_current == null || _queue.isEmpty) return _current;
    final index = _queue.indexWhere((song) => song.id == _current!.id);
    if (index == -1) return _queue.last;
    for (var i = index - 1; i >= 0; i--) {
      if (!skipUnplayable || !_unplayableIds.contains(_queue[i].id)) {
        return _queue[i];
      }
    }
    if (_repeatMode != PlaybackRepeatMode.all) return null;
    for (var i = _queue.length - 1; i >= index; i--) {
      if (!skipUnplayable || !_unplayableIds.contains(_queue[i].id)) {
        return _queue[i];
      }
    }
    return null;
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
