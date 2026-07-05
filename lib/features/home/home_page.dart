import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/home_snapshot.dart';
import '../../core/models/playlist.dart';
import '../../core/services/music_api.dart';
import '../../core/widgets/cover_art.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/song_tile.dart';
import '../../player/player_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<HomeSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = context.read<MusicApi>().getHomeSnapshot();
  }

  Future<void> _refresh() async {
    setState(() {
      _snapshot = context.read<MusicApi>().getHomeSnapshot();
    });
    await _snapshot;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return FutureBuilder<HomeSnapshot>(
      future: _snapshot,
      builder: (context, state) {
        if (state.connectionState == ConnectionState.waiting && !state.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.hasError) {
          return _ErrorState(message: '${state.error}', onRetry: _refresh);
        }

        final data = state.data ??
            const HomeSnapshot(banners: [], newSongs: [], playlists: []);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: EdgeInsets.fromLTRB(0, topPad + 8, 0, 160),
            children: [
              const _HomeHeader(),
              const SizedBox(height: 20),
              _HeroBanners(banners: data.banners),
              SectionHeader(
                title: 'Made For You',
                action: FilledButton.tonalIcon(
                  onPressed: data.playlists.isEmpty
                      ? null
                      : () async {
                          final songs = await context
                              .read<MusicApi>()
                              .playlistSongs(data.playlists.first.id);
                          if (songs.isNotEmpty && context.mounted) {
                            await context
                                .read<PlayerController>()
                                .playSong(songs.first, queue: songs);
                          }
                        },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Play All'),
                ),
              ),
              _PlaylistGrid(playlists: data.playlists.take(4).toList()),
              const SectionHeader(title: 'New Releases'),
              for (final song in data.newSongs.take(8))
                SongTile(song: song, queue: data.newSongs),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good music,',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'MuseHub',
                  style: GoogleFonts.sora(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBanners extends StatelessWidget {
  const _HeroBanners({required this.banners});

  final List<BannerItem> banners;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = banners.take(5).toList();

    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: scheme.surfaceContainerHigh,
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(20),
          child: Text(
            'MuseHub',
            style: GoogleFonts.sora(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
          child: Text(
            'Trending Now',
            style: GoogleFonts.sora(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.88),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final banner = visible[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                child: _BannerCard(banner: banner),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});

  final BannerItem banner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoverArt(url: banner.imageUrl, borderRadius: 0),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.3, 1.0],
                colors: [
                  Colors.transparent,
                  const Color(0xFF131312).withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FEATURED PLAYLIST',
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: scheme.primaryContainer,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  banner.title == 'Featured' ? 'Neon Nights Vol. 4' : banner.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A cinematic mix for late night listening.',
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
        ],
      ),
    );
  }
}

class _PlaylistGrid extends StatelessWidget {
  const _PlaylistGrid({required this.playlists});

  final List<MusicPlaylist> playlists;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: playlists.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.76,
      ),
      itemBuilder: (context, index) =>
          _PlaylistCard(playlist: playlists[index]),
    );
  }
}

class _PlaylistCard extends StatefulWidget {
  const _PlaylistCard({required this.playlist});

  final MusicPlaylist playlist;

  @override
  State<_PlaylistCard> createState() => _PlaylistCardState();
}

class _PlaylistCardState extends State<_PlaylistCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _loading
          ? null
          : () async {
              setState(() => _loading = true);
              try {
                final songs = await context
                    .read<MusicApi>()
                    .playlistSongs(widget.playlist.id);
                if (songs.isNotEmpty && context.mounted) {
                  await context
                      .read<PlayerController>()
                      .playSong(songs.first, queue: songs);
                }
              } finally {
                if (mounted) setState(() => _loading = false);
              }
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CoverArt(url: widget.playlist.coverUrl, borderRadius: 0),
                      if (_loading)
                        const ColoredBox(
                          color: Colors.black38,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.playlist.name,
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
            _formatPlayCount(widget.playlist.playCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPlayCount(int count) {
    if (count >= 100000000) {
      return '${(count / 100000000).toStringAsFixed(1)}B plays';
    }
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}W plays';
    return '$count plays';
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
