import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/models/lyric_line.dart';
import '../core/models/song.dart';
import '../core/services/music_api.dart';

enum RepeatMode { off, one, all }

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
  RepeatMode _repeatMode = RepeatMode.all;

  List<Song> get queue => List.unmodifiable(_queue);
  Song? get current => _current;
  List<LyricLine> get lyrics => List.unmodifiable(_lyrics);
  Duration get position => _position;
  Duration get duration => _duration;
  bool get isPlaying => _isPlaying;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RepeatMode get repeatMode => _repeatMode;

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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final url = await _api.songUrl(song.id);
      if (url == null) {
        throw const MusicApiException('No playable URL returned for this song.');
      }
      await _audio.setUrl(url);
      await _audio.play();
      _lyrics = await _api.lyrics(song.id);
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (_current == null) return;
    if (_audio.playing) {
      await _audio.pause();
    } else {
      await _audio.play();
    }
  }

  Future<void> seek(Duration position) => _audio.seek(position);

  Future<void> next() async {
    final song = _nextSong();
    if (song != null) await playSong(song);
  }

  Future<void> previous() async {
    final song = _previousSong();
    if (song != null) await playSong(song);
  }

  void cycleRepeatMode() {
    _repeatMode = switch (_repeatMode) {
      RepeatMode.off => RepeatMode.one,
      RepeatMode.one => RepeatMode.all,
      RepeatMode.all => RepeatMode.off,
    };
    notifyListeners();
  }

  Song? _nextSong() {
    if (_current == null || _queue.isEmpty) return _current;
    if (_repeatMode == RepeatMode.one) return _current;
    final index = _queue.indexWhere((song) => song.id == _current!.id);
    if (index == -1) return _queue.first;
    if (index + 1 < _queue.length) return _queue[index + 1];
    return _repeatMode == RepeatMode.all ? _queue.first : null;
  }

  Song? _previousSong() {
    if (_current == null || _queue.isEmpty) return _current;
    final index = _queue.indexWhere((song) => song.id == _current!.id);
    if (index > 0) return _queue[index - 1];
    return _repeatMode == RepeatMode.all ? _queue.last : null;
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
