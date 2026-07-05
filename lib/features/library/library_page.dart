import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final topPad = MediaQuery.paddingOf(context).top;
    final ids = context.watch<AppState>().favoriteIds;

    if (ids.isEmpty) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.favorite_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Your favorites',
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Favorite songs from Home, Search, or the player will appear here.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
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
          padding: EdgeInsets.fromLTRB(0, topPad + 8, 0, 160),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Favorites',
                style: GoogleFonts.sora(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.8,
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final song in songs) SongTile(song: song, queue: songs),
          ],
        );
      },
    );
  }
}
