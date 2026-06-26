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
      appBar: AppBar(
        title: const Text('Now playing'),
        actions: [
          IconButton(
            tooltip: appState.isFavorite(song) ? 'Remove favorite' : 'Favorite',
            icon: Icon(appState.isFavorite(song) ? Icons.favorite : Icons.favorite_border),
            onPressed: () => appState.toggleFavorite(song),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: CoverArt(url: song.coverUrl, borderRadius: 8),
            ),
            const SizedBox(height: 24),
            Text(
              song.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              song.artistText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Slider(
              value: progress.clamp(0.0, 1.0).toDouble(),
              onChanged: (value) => player.seek(
                Duration(milliseconds: (player.duration.inMilliseconds * value).round()),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_format(player.position)),
                Text(_format(player.duration)),
              ],
            ),
            const SizedBox(height: 18),
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
                  iconSize: 42,
                  icon: Icon(player.isPlaying ? Icons.pause : Icons.play_arrow),
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
            const SizedBox(height: 24),
            Text(
              player.activeLyric?.text ?? 'Lyrics will appear when available.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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

  static IconData _repeatIcon(RepeatMode mode) {
    return switch (mode) {
      RepeatMode.off => Icons.repeat,
      RepeatMode.one => Icons.repeat_one,
      RepeatMode.all => Icons.repeat_on,
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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final song in player.queue)
              ListTile(
                title: Text(song.name),
                subtitle: Text(song.artistText),
                leading: song.id == player.current?.id ? const Icon(Icons.graphic_eq) : null,
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
