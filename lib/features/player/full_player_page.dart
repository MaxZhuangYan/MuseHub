import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/widgets/cover_art.dart';
import '../../player/player_controller.dart';

class FullPlayerPage extends StatelessWidget {
  const FullPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Nothing is playing')),
      );
    }

    final appState = context.watch<AppState>();
    final progress = player.duration.inMilliseconds == 0
        ? 0.0
        : player.position.inMilliseconds / player.duration.inMilliseconds;

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          color: scheme.onSurface,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              'NOW PLAYING',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              'MuseHub',
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: appState.isFavorite(song) ? 'Remove favorite' : 'Favorite',
            icon: Icon(
              appState.isFavorite(song)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: appState.isFavorite(song)
                  ? scheme.primaryContainer
                  : scheme.onSurfaceVariant,
            ),
            onPressed: () => appState.toggleFavorite(song),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.55, 1.0],
            colors: [
              const Color(0xFF1E1A14),
              const Color(0xFF161513),
              scheme.surface,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.paddingOf(context).top + 88, 24, 48),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 56,
                      offset: const Offset(0, 28),
                    ),
                  ],
                ),
                child: CoverArt(url: song.coverUrl, borderRadius: 20),
              ),
            ),
            const SizedBox(height: 28),
            _InfoPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.sora(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artistText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.hankenGrotesk(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: scheme.primaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: appState.isFavorite(song)
                            ? 'Remove favorite'
                            : 'Favorite',
                        icon: Icon(
                          appState.isFavorite(song)
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color: appState.isFavorite(song)
                              ? scheme.primaryContainer
                              : scheme.onSurfaceVariant,
                          size: 26,
                        ),
                        onPressed: () => appState.toggleFavorite(song),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Slider(
                    value: progress.clamp(0.0, 1.0).toDouble(),
                    onChanged: (value) => player.seek(
                      Duration(
                          milliseconds:
                              (player.duration.inMilliseconds * value).round()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _format(player.position),
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _format(player.duration),
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (player.error != null) ...[
                    Text(
                      player.error!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ControlButton(
                        tooltip: 'Repeat',
                        icon: _repeatIcon(player.repeatMode),
                        onPressed: player.cycleRepeatMode,
                        isActive: player.repeatMode != PlaybackRepeatMode.off,
                      ),
                      IconButton(
                        tooltip: 'Previous',
                        iconSize: 32,
                        icon: const Icon(Icons.skip_previous_rounded),
                        color: scheme.onSurface,
                        onPressed: player.previous,
                      ),
                      _PlayPauseButton(player: player),
                      IconButton(
                        tooltip: 'Next',
                        iconSize: 32,
                        icon: const Icon(Icons.skip_next_rounded),
                        color: scheme.onSurface,
                        onPressed: player.next,
                      ),
                      _ControlButton(
                        tooltip: 'Queue',
                        icon: Icons.queue_music_rounded,
                        onPressed: () => _showQueue(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (player.activeLyric != null || player.lyrics.isNotEmpty) ...[
              Text(
                player.activeLyric?.text ?? '',
                textAlign: TextAlign.center,
                style: GoogleFonts.sora(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              for (final line in player.lyrics.take(40))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                    line.text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 14,
                      color: line == player.activeLyric
                          ? scheme.primaryContainer
                          : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontWeight: line == player.activeLyric
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
            ] else
              Text(
                'Lyrics will appear when available.',
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _repeatIcon(PlaybackRepeatMode mode) {
    return switch (mode) {
      PlaybackRepeatMode.off => Icons.repeat_rounded,
      PlaybackRepeatMode.one => Icons.repeat_one_rounded,
      PlaybackRepeatMode.all => Icons.repeat_on_rounded,
    };
  }

  static String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showQueue(BuildContext context) {
    final player = context.read<PlayerController>();
    final scheme = Theme.of(context).colorScheme;
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
                'Queue',
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
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF252523),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: player.toggle,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(
          player.error != null
              ? Icons.replay_rounded
              : player.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
          color: scheme.onPrimaryContainer,
          size: 38,
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isActive = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      color: isActive ? scheme.primaryContainer : scheme.onSurfaceVariant,
      iconSize: 22,
      onPressed: onPressed,
    );
  }
}
