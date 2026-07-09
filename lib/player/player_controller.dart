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
        unawaited(_handlePlaybackCompleted());
      } else if (state.processingState != ProcessingState.completed) {
        _completionHandled = false;
      }
      notifyListeners();
    });
    _stallWatchdog = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkPlaybackStall(),
    );
  }

  static const _audioStreamHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Referer': 'https://music.163.com/',
  };
  static const _maxStallRecoveriesPerTrack = 2;

  final MusicApi _api;
  final DownloadService _downloads;
  final AudioPlayer _audio = AudioPlayer(
    // just_audio's default header path creates a cleartext localhost proxy.
    // On some Android debug/Studio builds that proxy can fail before its
    // internal HttpServer is assigned, surfacing as a LateInitializationError.
    // Android/iOS/macOS can send these headers natively, so avoid the proxy.
    useProxyForRequestHeaders: false,
  );
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
  int _errorVersion = 0;
  PlaybackRepeatMode _repeatMode = PlaybackRepeatMode.all;
  int _playRequestId = 0;
  Duration? _lastWatchdogPosition;
  int _stalledTicks = 0;
  int _stallRecoveryAttempts = 0;
  bool _recoveringStall = false;
  bool _completionHandled = false;
  String? _currentAudioSource;

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

  /// Bumped every time a fresh playback failure occurs, even if the error
  /// message text is identical to the previous one (e.g. retrying the same
  /// VIP-locked track). UI can key a one-shot notification off this instead
  /// of the message string, which would otherwise de-dupe repeat failures.
  int get errorVersion => _errorVersion;
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

  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    bool automatic = false,
    int automaticSkipCount = 0,
  }) async {
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
    _completionHandled = false;
    _currentAudioSource = null;
    _stallRecoveryAttempts = 0;
    _resetStallWatchdog();
    notifyListeners();

    // Kick off palette extraction in parallel; result notifies independently
    unawaited(_extractAmbientColor(song.coverUrl));

    try {
      await _audio.stop();
      if (!_isCurrentRequest(requestId, song.id)) return;

      // Hydrating missing cover/artist metadata and resolving the playable
      // audio URL are independent — audio resolution only needs the song id
      // and duration, both already known. Running them in parallel instead
      // of serially cuts a full network round trip off the time-to-first-
      // sound on every play.
      unawaited(_loadLyrics(song.id, requestId));
      final hydrateFuture = _hydrateSongForPlayback(song);
      // A fresh/manual play (including the user tapping play again after a
      // failure) is a strong signal to retry the Alger resolver even if it
      // had a recent hiccup — only automatic stall-recovery respects the
      // cooldown, to avoid hammering a resolver that's genuinely down.
      final loadAudioFuture = _loadAudioSource(
        song,
        requestId,
        bypassResolverCooldown: true,
      );

      final hydratedSong = await hydrateFuture;
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

      await loadAudioFuture;
      if (!_isCurrentRequest(requestId, song.id)) return;
      await _audio.play();
    } catch (error) {
      if (!_isCurrentRequest(requestId, song.id)) return;
      await _audio.stop();
      if (!_isCurrentRequest(requestId, song.id)) return;
      if (automatic &&
          await _skipCurrentQueueTrack(
            song,
            requestId,
            automaticSkipCount,
          )) {
        return;
      }
      _position = Duration.zero;
      _isPlaying = false;
      _error = error.toString();
      _errorVersion++;
    } finally {
      if (_isCurrentRequest(requestId, song.id)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadAudioSource(
    Song song,
    int requestId, {
    bool bypassResolverCooldown = false,
  }) async {
    final localPath = await _localPathForSong(song.id);
    if (!_isCurrentRequest(requestId, song.id)) return;
    if (localPath != null) {
      try {
        await _audio
            .setFilePath(localPath)
            .timeout(const Duration(seconds: 12));
        return;
      } on Object {
        // Fall through to online candidates — a corrupted/moved download
        // shouldn't be a dead end when the song might still stream fine.
      }
    }

    // Playability is the goal, not stopping at the first "probably fine"
    // candidate: a URL that passed MusicApi's lightweight validation can
    // still fail once the player does a real GET against it (some CDNs
    // behave differently for HEAD/range probes than full playback). Try
    // every remaining candidate for real before finally giving up.
    var triedAny = false;
    Object? lastError;
    await for (final candidate in _api.resolveAudioSourceCandidates(
      song,
      bypassResolverCooldown: bypassResolverCooldown,
    )) {
      if (!_isCurrentRequest(requestId, song.id)) return;
      triedAny = true;
      try {
        // Netease's CDN enforces Referer-based hotlink protection on some
        // edges — most visibly on realIP-unlocked URLs, which are already
        // bypassing a restriction and so get checked more strictly. Our own
        // validation probe sends these headers and passes; without them
        // here too, just_audio's request can come back empty/blocked even
        // though resolution "succeeded". Same convention as CoverArt.
        //
        await _audio
            .setUrl(
              candidate.url,
              headers: _audioStreamHeaders,
            )
            .timeout(const Duration(seconds: 20));
        _currentAudioSource = candidate.source;
        _api.confirmWorkingSource(song.id, candidate);
        return;
      } on Object catch (error) {
        lastError = error;
        // Try the next candidate instead of giving up on the first miss.
      }
    }

    if (!_isCurrentRequest(requestId, song.id)) return;
    if (!triedAny) {
      // Every method — including the compatible API's VIP/region unlock —
      // came back empty. Enabling the Alger resolver in Settings adds one
      // more independent source worth trying for genuinely hard cases.
      if (song.requiresPaidAccess && _api.resolverBaseUrl.isEmpty) {
        throw const MusicApiException(
          'This VIP-only track could not be unlocked. Enabling the Alger '
          'fallback resolver in Settings may find it on another source.',
        );
      }
      throw const MusicApiException(
        'This track is unavailable from the current music source.',
      );
    }
    throw MusicApiException('$lastError');
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

  Future<void> _handlePlaybackCompleted() async {
    if (_completionHandled ||
        _isLoading ||
        _recoveringStall ||
        _current == null) {
      return;
    }
    _completionHandled = true;
    await next(automatic: true);
  }

  Future<bool> _skipCurrentQueueTrack(
    Song failedSong,
    int requestId,
    int automaticSkipCount,
  ) async {
    if (!_isCurrentRequest(requestId, failedSong.id)) return true;
    if (_repeatMode == PlaybackRepeatMode.one || _queue.length < 2) {
      return false;
    }
    if (automaticSkipCount >= _queue.length - 1) return false;

    final nextSong = _nextSong(respectRepeatOne: false);
    if (nextSong == null || nextSong.id == failedSong.id) return false;

    await playSong(
      nextSong,
      automatic: true,
      automaticSkipCount: automaticSkipCount + 1,
    );
    return true;
  }

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
    // 2 ticks @ 3s = ~6s of visibly stuck playback before we intervene —
    // down from the previous 12s. Recovery itself is now much faster too
    // (MusicApi retries the last-known-good source first), so shortening
    // detection no longer risks a slow, disruptive recovery for what might
    // just be a brief buffering blip.
    if (_stalledTicks >= 2) {
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
    _stallRecoveryAttempts += 1;
    if (_stallRecoveryAttempts > _maxStallRecoveriesPerTrack) {
      if (await _skipCurrentQueueTrack(song, requestId, 0)) {
        return;
      }
      await _audio.stop();
      if (!_isCurrentRequest(requestId, song.id)) return;
      _isPlaying = false;
      _error = 'Playback stalled and no next track is available.';
      _errorVersion++;
      notifyListeners();
      return;
    }
    final resumeAt = _position;
    _api.temporarilyBlockSource(song.id, _currentAudioSource);
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
      _errorVersion++;
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
    if (song != null) {
      await playSong(song, automatic: automatic);
    } else if (automatic) {
      await _audio.stop();
      _position = Duration.zero;
      _isPlaying = false;
      notifyListeners();
    }
  }

  Future<void> previous() async {
    final song = _previousSong();
    if (song != null) await playSong(song);
  }

  void cycleRepeatMode() {
    _repeatMode = switch (_repeatMode) {
      PlaybackRepeatMode.off => PlaybackRepeatMode.all,
      PlaybackRepeatMode.all => PlaybackRepeatMode.one,
      PlaybackRepeatMode.one => PlaybackRepeatMode.off,
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
