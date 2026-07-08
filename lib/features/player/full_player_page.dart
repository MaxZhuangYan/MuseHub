import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/models/lyric_line.dart';
import '../../core/theme.dart';
import '../../core/widgets/cover_art.dart';
import '../../l10n/app_strings.dart';
import '../../player/player_controller.dart';

/// Full-screen "Now Playing" — dark, cohesive with the rest of the app.
/// A vibrant color pulled from the artwork tints the artist name, the
/// faint top glow, and the progress fill. Everything else stays black.
class FullPlayerPage extends StatefulWidget {
  const FullPlayerPage({super.key});

  @override
  State<FullPlayerPage> createState() => _FullPlayerPageState();
}

class _FullPlayerPageState extends State<FullPlayerPage> {
  Color _vibrant = MuseTheme.accentSoft;
  String? _loadedUrl;

  void _maybeLoadPalette(String url) {
    if (url.isEmpty || url == _loadedUrl) return;
    _loadedUrl = url;
    _loadPalette(url);
  }

  Future<void> _loadPalette(String url) async {
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(100, 100),
        maximumColorCount: 20,
      );
      if (!mounted || _loadedUrl != url) return;
      final color = palette.lightVibrantColor?.color ??
          palette.vibrantColor?.color ??
          palette.dominantColor?.color;
      if (color == null) return;
      // Ensure it reads clearly on black — lift lightness if too dark.
      final hsl = HSLColor.fromColor(color);
      setState(() {
        _vibrant = hsl
            .withLightness(hsl.lightness.clamp(0.55, 0.78))
            .withSaturation(max(hsl.saturation, 0.45))
            .toColor();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final strings = AppStrings.of(context);
    final song = player.current;

    if (song != null) _maybeLoadPalette(song.coverUrl);

    if (song == null) {
      return Scaffold(
        backgroundColor: MuseTheme.bg,
        appBar: AppBar(),
        body: Center(child: Text(strings.nothingPlaying)),
      );
    }

    final appState = context.watch<AppState>();
    final progress = player.duration.inMilliseconds == 0
        ? 0.0
        : player.position.inMilliseconds / player.duration.inMilliseconds;
    final remaining = player.duration - player.position;

    return Scaffold(
      backgroundColor: MuseTheme.bg,
      body: Stack(
        children: [
          // Faint artwork-colored glow at the very top for depth.
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.85),
                  radius: 1.1,
                  colors: [
                    _vibrant.withValues(alpha: 0.16),
                    MuseTheme.bg.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final artworkSize =
                    (constraints.maxWidth - 96).clamp(220.0, 360.0).toDouble();
                return Column(
                  children: [
                    _TopBar(
                      label: strings.nowPlaying,
                      title: strings.appName,
                      onClose: () => Navigator.of(context).pop(),
                      onMore: () => _showQueue(context),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // ── Artwork ──
                            Hero(
                              tag: 'miniplayer_cover',
                              child: Container(
                                width: artworkSize,
                                height: artworkSize,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _vibrant.withValues(alpha: 0.28),
                                      blurRadius: 60,
                                      spreadRadius: -8,
                                      offset: const Offset(0, 24),
                                    ),
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.5),
                                      blurRadius: 30,
                                      offset: const Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: CoverArt(
                                    url: song.coverUrl, borderRadius: 24),
                              ),
                            ),

                            // ── Title + artist + fav ──
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.sora(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: MuseTheme.textPrimary,
                                          height: 1.1,
                                          letterSpacing: -0.8,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      AnimatedDefaultTextStyle(
                                        duration:
                                            const Duration(milliseconds: 500),
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          color: _vibrant,
                                        ),
                                        child: Text(
                                          song.artistText,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _DownloadButton(appState: appState, song: song),
                                _FavButton(appState: appState, song: song),
                              ],
                            ),

                            // ── Progress ──
                            Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: MuseTheme.textPrimary,
                                    inactiveTrackColor: MuseTheme.textPrimary
                                        .withValues(alpha: 0.16),
                                    thumbColor: MuseTheme.textPrimary,
                                    overlayColor: MuseTheme.textPrimary
                                        .withValues(alpha: 0.12),
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 14),
                                  ),
                                  child: Slider(
                                    value: progress.clamp(0.0, 1.0).toDouble(),
                                    onChanged: (v) => player.seek(
                                      Duration(
                                        milliseconds:
                                            (player.duration.inMilliseconds * v)
                                                .round(),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _TimeLabel(_format(player.position)),
                                      _TimeLabel(
                                        '-${_format(remaining.isNegative ? Duration.zero : remaining)}',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // ── Controls ──
                            _Controls(
                              player: player,
                              onShowQueue: () => _showQueue(context),
                            ),

                            // ── Bottom row: lyrics pill + queue ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _LyricsPill(
                                  label: strings.lyrics,
                                  onPressed: player.lyrics.isEmpty
                                      ? null
                                      : () => _showLyrics(context),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showQueue(BuildContext context) {
    final player = context.read<PlayerController>();
    final strings = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: MuseTheme.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              strings.queue,
              style: GoogleFonts.sora(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: MuseTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
          ),
          for (final s in player.queue)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
              title: Text(
                s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: s.id == player.current?.id
                      ? _vibrant
                      : MuseTheme.textPrimary,
                ),
              ),
              subtitle: Text(
                s.artistText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 12, color: MuseTheme.textSecondary),
              ),
              leading: s.id == player.current?.id
                  ? Icon(Icons.graphic_eq_rounded, color: _vibrant)
                  : const Icon(Icons.drag_indicator_rounded,
                      color: MuseTheme.textSecondary),
              onTap: () {
                Navigator.of(context).pop();
                player.playSong(s);
              },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showLyrics(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: MuseTheme.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _LyricsSheet(accent: _vibrant),
    );
  }
}

/// Lyrics sheet content that stays subscribed to playback progress and keeps
/// the active line centered unless the user is manually browsing lyrics.
class _LyricsSheet extends StatefulWidget {
  const _LyricsSheet({required this.accent});
  final Color accent;

  @override
  State<_LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<_LyricsSheet> {
  final _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  LyricLine? _lastScrolledLine;
  Timer? _resumeTrackingTimer;
  bool _userBrowsing = false;
  bool _autoScrolling = false;

  @override
  void dispose() {
    _resumeTrackingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToActiveLine(
    LyricLine? active,
    List<LyricLine> lyrics, {
    bool force = false,
  }) {
    if (active == null || (_userBrowsing && !force)) return;
    if (!force && identical(active, _lastScrolledLine)) return;
    final index = lyrics.indexOf(active);
    if (index == -1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final lineContext = _lineKeys[index]?.currentContext;
      if (lineContext == null) return;
      _lastScrolledLine = active;
      _autoScrolling = true;
      Scrollable.ensureVisible(
        lineContext,
        alignment: 0.46,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      ).whenComplete(() {
        if (mounted) _autoScrolling = false;
      });
    });
  }

  void _pauseTracking(LyricLine? active, List<LyricLine> lyrics) {
    if (!_userBrowsing) {
      setState(() => _userBrowsing = true);
    }
    _resumeTrackingTimer?.cancel();
    _resumeTrackingTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _userBrowsing = false);
      _scheduleScrollToActiveLine(active, lyrics, force: true);
    });
  }

  bool _isManualScroll(ScrollNotification notification) {
    if (_autoScrolling) return false;
    if (notification is UserScrollNotification) {
      return notification.direction != ScrollDirection.idle;
    }
    return (notification is ScrollStartNotification &&
            notification.dragDetails != null) ||
        (notification is ScrollUpdateNotification &&
            notification.dragDetails != null);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final strings = AppStrings.of(context);
    final lyrics = player.lyrics;
    final active = player.activeLyric;

    _scheduleScrollToActiveLine(active, lyrics);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (_isManualScroll(notification)) {
          _pauseTracking(active, lyrics);
        }
        return false;
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
        children: [
          Text(
            strings.lyrics,
            style: GoogleFonts.sora(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: MuseTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          if (lyrics.isEmpty)
            Text(
              strings.lyricsUnavailable,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 14,
                color: MuseTheme.textSecondary,
              ),
            )
          else
            for (var i = 0; i < lyrics.length; i++)
              _LyricLineTile(
                key: _lineKeys.putIfAbsent(i, () => GlobalKey()),
                line: lyrics[i],
                isActive: lyrics[i] == active,
                accent: widget.accent,
                onTap: () {
                  unawaited(player.seek(lyrics[i].time));
                  _resumeTrackingTimer?.cancel();
                  setState(() => _userBrowsing = false);
                  _scheduleScrollToActiveLine(lyrics[i], lyrics, force: true);
                },
              ),
        ],
      ),
    );
  }
}

class _LyricLineTile extends StatelessWidget {
  const _LyricLineTile({
    super.key,
    required this.line,
    required this.isActive,
    required this.accent,
    required this.onTap,
  });

  final LyricLine line;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(vertical: isActive ? 9 : 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            style: GoogleFonts.hankenGrotesk(
              fontSize: isActive ? 18 : 16,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              height: 1.28,
              color: isActive
                  ? accent
                  : MuseTheme.textPrimary.withValues(alpha: 0.42),
            ),
            child: Text(
              line.text,
              textAlign: TextAlign.center,
              softWrap: true,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.label,
    required this.title,
    required this.onClose,
    required this.onMore,
  });
  final String label, title;
  final VoidCallback onClose, onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SizedBox(
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                iconSize: 30,
                color: MuseTheme.textPrimary,
                onPressed: onClose,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: MuseTheme.textSecondary,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MuseTheme.textPrimary,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: AppStrings.of(context).queue,
                icon: const Icon(Icons.more_horiz_rounded),
                iconSize: 26,
                color: MuseTheme.textPrimary,
                onPressed: onMore,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Favorite ──────────────────────────────────────────────────────────────────

class _FavButton extends StatelessWidget {
  const _FavButton({required this.appState, required this.song});
  final AppState appState;
  final dynamic song;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isFav = appState.isFavorite(song);
    return IconButton(
      tooltip: isFav ? strings.removeFavorite : strings.favorite,
      icon: Icon(
        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isFav ? MuseTheme.accent : MuseTheme.textSecondary,
        size: 28,
      ),
      onPressed: () => appState.toggleFavorite(song),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.appState, required this.song});
  final AppState appState;
  final dynamic song;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isDownloaded = appState.isDownloaded(song);
    final isDownloading = appState.isDownloading(song);
    return IconButton(
      tooltip: isDownloading
          ? strings.downloading
          : isDownloaded
              ? strings.downloaded
              : strings.download,
      icon: isDownloading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isDownloaded
                  ? Icons.download_done_rounded
                  : Icons.download_rounded,
              color: isDownloaded ? MuseTheme.accent : MuseTheme.textSecondary,
              size: 26,
            ),
      onPressed:
          isDownloading || isDownloaded ? null : () => _runDownload(context),
    );
  }

  Future<void> _runDownload(BuildContext context) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await appState.downloadSong(song);
    } on Object {
      messenger.showSnackBar(
        SnackBar(content: Text(strings.downloadFailed)),
      );
    }
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: MuseTheme.textSecondary,
      ),
    );
  }
}

// ── Controls ──────────────────────────────────────────────────────────────────

class _Controls extends StatelessWidget {
  const _Controls({required this.player, required this.onShowQueue});
  final PlayerController player;
  final VoidCallback onShowQueue;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300;
        final edgeSize = compact ? 38.0 : 44.0;
        final skipSize = compact ? 40.0 : 48.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Ctrl(
              tooltip: strings.repeat,
              icon: _repeatIcon(player.repeatMode),
              onPressed: player.cycleRepeatMode,
              isActive: player.repeatMode != PlaybackRepeatMode.off,
              size: edgeSize,
            ),
            _Ctrl(
              tooltip: strings.previous,
              icon: Icons.skip_previous_rounded,
              onPressed: player.previous,
              size: skipSize,
            ),
            _PlayButton(
              player: player,
              size: compact ? 64 : 76,
              iconSize: compact ? 32 : 38,
            ),
            _Ctrl(
              tooltip: strings.next,
              icon: Icons.skip_next_rounded,
              onPressed: player.next,
              size: skipSize,
            ),
            _Ctrl(
              tooltip: strings.queue,
              icon: Icons.queue_music_rounded,
              onPressed: onShowQueue,
              size: edgeSize,
            ),
          ],
        );
      },
    );
  }

  static IconData _repeatIcon(PlaybackRepeatMode mode) => switch (mode) {
        PlaybackRepeatMode.off => Icons.repeat_rounded,
        PlaybackRepeatMode.one => Icons.repeat_one_rounded,
        PlaybackRepeatMode.all => Icons.repeat_rounded,
      };
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.player,
    required this.size,
    required this.iconSize,
  });

  final PlayerController player;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final icon = player.error != null
        ? Icons.replay_rounded
        : player.isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MuseTheme.accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: MuseTheme.accent.withValues(alpha: 0.5),
            blurRadius: 28,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: player.isLoading && !player.isPlaying
          ? Padding(
              padding: EdgeInsets.all(size * 0.29),
              child: const CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : InkResponse(
              radius: size * 0.52,
              onTap: player.toggle,
              child: Icon(icon, color: Colors.white, size: iconSize),
            ),
    );
  }
}

class _Ctrl extends StatelessWidget {
  const _Ctrl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.size,
    this.isActive = false,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? MuseTheme.accent : MuseTheme.textPrimary;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size + 8,
        child: InkResponse(
          radius: size * 0.55,
          onTap: onPressed,
          child: Icon(icon, color: color, size: size * 0.72),
        ),
      ),
    );
  }
}

// ── Lyrics pill ───────────────────────────────────────────────────────────────

class _LyricsPill extends StatelessWidget {
  const _LyricsPill({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: MuseTheme.surface2,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lyrics_rounded,
                  size: 16,
                  color: enabled
                      ? MuseTheme.textPrimary
                      : MuseTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: enabled
                      ? MuseTheme.textPrimary
                      : MuseTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
