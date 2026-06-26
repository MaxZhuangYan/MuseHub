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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CoverArt(url: song.coverUrl, size: 48),
      title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        song.artistText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing ??
          IconButton(
            tooltip: isFavorite ? 'Remove favorite' : 'Favorite',
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
            onPressed: () => appState.toggleFavorite(song),
          ),
      onTap: () => context.read<PlayerController>().playSong(song, queue: queue),
    );
  }
}
