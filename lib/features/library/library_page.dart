import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/models/song.dart';
import '../../core/services/music_api.dart';
import '../../core/widgets/song_tile.dart';
import '../../l10n/app_strings.dart';

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

  Widget _buildHeader(BuildContext context,
      {required Set<int> ids, double topPad = 0}) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.favorites,
            style: GoogleFonts.sora(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -0.8,
            ),
          ),
          if (ids.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              strings.savedLocally(ids.length),
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final ids = context.watch<AppState>().favoriteIds;
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (ids.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, ids: ids, topPad: topPad),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              scheme.primaryContainer.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        Icons.favorite_outline_rounded,
                        size: 30,
                        color: scheme.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      strings.yourFavorites,
                      style: GoogleFonts.sora(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.favoritesEmpty,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return FutureBuilder<List<Song>>(
      future: _favorites,
      builder: (context, state) {
        if (state.connectionState == ConnectionState.waiting && !state.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, ids: ids, topPad: topPad),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        final songs = state.data ?? const [];
        return ListView(
          padding: EdgeInsets.fromLTRB(0, topPad + 8, 0, 160),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.favorites,
                    style: GoogleFonts.sora(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    strings.savedLocally(ids.length),
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(
                height: 1,
                color: scheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
            const SizedBox(height: 4),
            for (final song in songs) SongTile(song: song, queue: songs),
          ],
        );
      },
    );
  }
}
