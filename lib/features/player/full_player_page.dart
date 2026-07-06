import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/widgets/cover_art.dart';
import '../../l10n/app_strings.dart';
import '../../player/player_controller.dart';

class FullPlayerPage extends StatelessWidget {
  const FullPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final strings = AppStrings.of(context);
    final song = player.current;
    if (song == null) {
      return Scaffold(
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
      backgroundColor: const Color(0xFFDBA3C1),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFB277D0),
              Color(0xFFD59ABA),
              Color(0xFFFFC3AD),
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth =
                  (constraints.maxWidth - 40).clamp(300.0, 430.0).toDouble();
              final artworkSize = (contentWidth - 56)
                  .clamp(220.0, constraints.maxHeight * 0.42)
                  .toDouble();

              return Center(
                child: SizedBox(
                  width: contentWidth,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
                    children: [
                      _PlayerTopBar(
                        title: strings.nowPlaying,
                        subtitle: strings.appName,
                        onClose: () => Navigator.of(context).pop(),
                        onMore: () => _showQueue(context),
                      ),
                      const SizedBox(height: 34),
                      Center(
                        child: SizedBox.square(
                          dimension: artworkSize,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.24),
                                  blurRadius: 34,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child:
                                CoverArt(url: song.coverUrl, borderRadius: 28),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      _GlassPanel(
                        child: Column(
                          children: [
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
                                          fontSize: 25,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        song.artistText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.hankenGrotesk(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF61F1F2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: appState.isFavorite(song)
                                      ? strings.removeFavorite
                                      : strings.favorite,
                                  icon: Icon(
                                    appState.isFavorite(song)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                  ),
                                  color: Colors.white,
                                  iconSize: 30,
                                  onPressed: () =>
                                      appState.toggleFavorite(song),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: Colors.white,
                                inactiveTrackColor:
                                    Colors.white.withValues(alpha: 0.34),
                                thumbColor: Colors.white,
                                overlayColor:
                                    Colors.white.withValues(alpha: 0.12),
                                trackHeight: 5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                ),
                              ),
                              child: Slider(
                                value: progress.clamp(0.0, 1.0).toDouble(),
                                onChanged: (value) => player.seek(
                                  Duration(
                                    milliseconds:
                                        (player.duration.inMilliseconds * value)
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
                                      '-${_format(remaining.isNegative ? Duration.zero : remaining)}'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            _PlayerControls(
                              player: player,
                              onShowQueue: () => _showQueue(context),
                            ),
                            const SizedBox(height: 18),
                            _LyricsButton(
                              label: strings.lyrics,
                              onPressed: player.lyrics.isEmpty
                                  ? null
                                  : () => _showLyrics(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _LyricsPreview(
                        player: player,
                        fallback: strings.lyricsUnavailable,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  static String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showQueue(BuildContext context) {
    final player = context.read<PlayerController>();
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF1F201E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                strings.queue,
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            for (final song in player.queue)
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                title: Text(
                  song.name,
                  style: GoogleFonts.sora(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: song.id == player.current?.id
                        ? scheme.primaryContainer
                        : scheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  song.artistText,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                leading: song.id == player.current?.id
                    ? Icon(Icons.graphic_eq, color: scheme.primaryContainer)
                    : null,
                onTap: () {
                  Navigator.of(context).pop();
                  player.playSong(song);
                },
              ),
          ],
        );
      },
    );
  }

  void _showLyrics(BuildContext context) {
    final player = context.read<PlayerController>();
    final strings = AppStrings.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFF2B2130),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final lyrics = player.lyrics;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          children: [
            Text(
              strings.lyrics,
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (lyrics.isEmpty)
              Text(
                strings.lyricsUnavailable,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              )
            else
              for (final line in lyrics)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    line.text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 15,
                      fontWeight: line == player.activeLyric
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: line == player.activeLyric
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.58),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.onMore,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _TopCircleButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: Icons.keyboard_arrow_down_rounded,
              onPressed: onClose,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withValues(alpha: 0.72),
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sora(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _TopCircleButton(
              tooltip: AppStrings.of(context).queue,
              icon: Icons.more_vert_rounded,
              onPressed: onMore,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon),
          color: Colors.white,
          iconSize: 27,
          style: IconButton.styleFrom(
            fixedSize: const Size(58, 58),
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.34),
                Colors.white.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(color: Colors.white.withValues(alpha: 0.34)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 36,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.player,
    required this.size,
  });

  final PlayerController player;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.28),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.42)),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: IconButton(
              tooltip: player.isPlaying
                  ? AppStrings.of(context).pause
                  : AppStrings.of(context).play,
              icon: Icon(
                player.error != null
                    ? Icons.replay_rounded
                    : player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
              ),
              color: Colors.white,
              iconSize: size * 0.49,
              onPressed:
                  player.isLoading && !player.isPlaying ? null : player.toggle,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerControls extends StatelessWidget {
  const _PlayerControls({
    required this.player,
    required this.onShowQueue,
  });

  final PlayerController player;
  final VoidCallback onShowQueue;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        final sideButtonSize = compact ? 40.0 : 46.0;
        final playButtonSize = compact ? 72.0 : 86.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _ControlButton(
              tooltip: strings.repeat,
              icon: Icon(_repeatIcon(player.repeatMode)),
              onPressed: player.cycleRepeatMode,
              isActive: player.repeatMode != PlaybackRepeatMode.off,
              size: sideButtonSize,
            ),
            _ControlButton(
              tooltip: strings.previous,
              icon: const Icon(Icons.skip_previous_rounded),
              onPressed: player.previous,
              size: sideButtonSize,
            ),
            _PlayPauseButton(player: player, size: playButtonSize),
            _ControlButton(
              tooltip: strings.next,
              icon: const Icon(Icons.skip_next_rounded),
              onPressed: player.next,
              size: sideButtonSize,
            ),
            _ControlButton(
              tooltip: strings.queue,
              icon: const Icon(Icons.queue_music_rounded),
              onPressed: onShowQueue,
              size: sideButtonSize,
            ),
          ],
        );
      },
    );
  }

  static IconData _repeatIcon(PlaybackRepeatMode mode) {
    return switch (mode) {
      PlaybackRepeatMode.off => Icons.repeat_rounded,
      PlaybackRepeatMode.one => Icons.repeat_one_rounded,
      PlaybackRepeatMode.all => Icons.repeat_on_rounded,
    };
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.size,
    this.isActive = false,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;
  final double size;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? Colors.white : Colors.white.withValues(alpha: 0.78);
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: size,
        child: IconTheme(
          data: IconThemeData(
            color: color,
            size: size * 0.61,
          ),
          child: InkResponse(
            radius: size * 0.52,
            onTap: onPressed,
            child: Center(child: icon),
          ),
        ),
      ),
    );
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
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Colors.white.withValues(alpha: 0.9),
      ),
    );
  }
}

class _LyricsButton extends StatelessWidget {
  const _LyricsButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: 170,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        label: Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.42),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.42)),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}

class _LyricsPreview extends StatelessWidget {
  const _LyricsPreview({
    required this.player,
    required this.fallback,
  });

  final PlayerController player;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final active = player.activeLyric;
    return Text(
      active?.text ?? fallback,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.white.withValues(alpha: active == null ? 0.54 : 0.82),
      ),
    );
  }
}
