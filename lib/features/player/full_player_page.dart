import 'package:flutter/material.dart';
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          children: [
            Text(
              'PLAYING FROM PLAYLIST',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
            ),
            const Text('MuseHub'),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: appState.isFavorite(song) ? 'Remove favorite' : 'Favorite',
            icon: Icon(appState.isFavorite(song)
                ? Icons.favorite
                : Icons.favorite_border),
            onPressed: () => appState.toggleFavorite(song),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF3A0A4C),
              Color(0xFF5C3DA4),
              Color(0xFF7D5BC4),
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.paddingOf(context).top + 88, 24, 32),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.42),
                      blurRadius: 48,
                      offset: const Offset(0, 24),
                    ),
                  ],
                ),
                child: CoverArt(url: song.coverUrl, borderRadius: 26),
              ),
            ),
            const SizedBox(height: 24),
            _GlassPanel(
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
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0,
                                  ),
                            ),
                            Text(
                              song.artistText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: const Color(0xFF7CF4FD),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: appState.isFavorite(song)
                            ? 'Remove favorite'
                            : 'Favorite',
                        icon: Icon(appState.isFavorite(song)
                            ? Icons.favorite
                            : Icons.favorite_border),
                        color: Colors.white,
                        iconSize: 32,
                        onPressed: () => appState.toggleFavorite(song),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Slider(
                    value: progress.clamp(0.0, 1.0).toDouble(),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.22),
                    onChanged: (value) => player.seek(
                      Duration(
                          milliseconds:
                              (player.duration.inMilliseconds * value).round()),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_format(player.position),
                          style: const TextStyle(color: Colors.white70)),
                      Text(_format(player.duration),
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (player.error != null) ...[
                    Text(
                      player.error!,
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Repeat',
                        icon: Icon(_repeatIcon(player.repeatMode)),
                        onPressed: player.cycleRepeatMode,
                      ),
                      IconButton(
                        tooltip: 'Previous',
                        iconSize: 36,
                        icon: const Icon(Icons.skip_previous),
                        onPressed: player.previous,
                      ),
                      IconButton.filled(
                        tooltip: player.isPlaying ? 'Pause' : 'Play',
                        iconSize: 52,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          foregroundColor: Colors.white,
                          fixedSize: const Size(82, 82),
                          side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.32)),
                        ),
                        icon: Icon(
                            player.isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: player.toggle,
                      ),
                      IconButton(
                        tooltip: 'Next',
                        iconSize: 36,
                        icon: const Icon(Icons.skip_next),
                        onPressed: player.next,
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Queue',
                        icon: const Icon(Icons.queue_music),
                        onPressed: () => _showQueue(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              player.activeLyric?.text ?? 'Lyrics will appear when available.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            for (final line in player.lyrics.take(40))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  line.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: line == player.activeLyric
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _repeatIcon(PlaybackRepeatMode mode) {
    return switch (mode) {
      PlaybackRepeatMode.off => Icons.repeat,
      PlaybackRepeatMode.one => Icons.repeat_one,
      PlaybackRepeatMode.all => Icons.repeat_on,
    };
  }

  static String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _showQueue(BuildContext context) {
    final player = context.read<PlayerController>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Queue',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final song in player.queue)
              ListTile(
                title: Text(song.name),
                subtitle: Text(song.artistText),
                leading: song.id == player.current?.id
                    ? const Icon(Icons.graphic_eq)
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

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(38),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 44,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: child,
    );
  }
}
