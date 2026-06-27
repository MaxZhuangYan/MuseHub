import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../player/player_controller.dart';
import '../app_state.dart';
import '../models/song.dart';
import 'cover_art.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    required this.song,
    required this.queue,
    this.trailing,
    super.key,
  });

  final Song song;
  final List<Song> queue;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isFavorite = appState.isFavorite(song);

    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: scheme.surfaceContainer.withValues(alpha: 0.58),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.06)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          leading: CoverArt(url: song.coverUrl, size: 52, borderRadius: 10),
          title: Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
          ),
          subtitle: Text(
            song.artistText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, letterSpacing: 0),
          ),
          trailing: trailing ??
              IconButton(
                tooltip: isFavorite ? 'Remove favorite' : 'Favorite',
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.more_horiz,
                  color: isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                ),
                onPressed: () => appState.toggleFavorite(song),
              ),
          onTap: () =>
              context.read<PlayerController>().playSong(song, queue: queue),
        ),
      ),
    );
  }
}
