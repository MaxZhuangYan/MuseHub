import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.read<PlayerController>().playSong(song, queue: queue),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CoverArt(url: song.coverUrl, size: 54, borderRadius: 0),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artistText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  IconButton(
                    tooltip: isFavorite ? 'Remove favorite' : 'More options',
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.more_horiz,
                      color: isFavorite
                          ? scheme.primaryContainer
                          : scheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onPressed: () => appState.toggleFavorite(song),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
