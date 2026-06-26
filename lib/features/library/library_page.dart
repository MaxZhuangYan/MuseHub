import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/models/song.dart';
import '../../core/services/music_api.dart';
import '../../core/widgets/song_tile.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  Future<List<Song>>? _favorites;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ids = context.watch<AppState>().favoriteIds.toList();
    _favorites = context.read<MusicApi>().songDetails(ids);
  }

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<AppState>().favoriteIds;
    if (ids.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Favorite songs from Home, Search, or the player will appear here.'),
        ),
      );
    }

    return FutureBuilder<List<Song>>(
      future: _favorites,
      builder: (context, state) {
        if (state.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final songs = state.data ?? const [];
        return ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text(
                'Favorites',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            for (final song in songs) SongTile(song: song, queue: songs),
          ],
        );
      },
    );
  }
}
