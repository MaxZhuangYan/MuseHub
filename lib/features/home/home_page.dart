import 'package:flutter/material.dart';
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
    return FutureBuilder<HomeSnapshot>(
      future: _snapshot,
      builder: (context, state) {
        if (state.connectionState == ConnectionState.waiting &&
            !state.hasData) {
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
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 124),
            children: [
              _HomeHeader(onSearch: () {}),
              const SizedBox(height: 14),
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
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
              ),
              _PlaylistGrid(playlists: data.playlists.take(4).toList()),
              const SectionHeader(title: 'New Releases'),
              for (final song in data.newSongs.take(8))
                SongTile(song: song, queue: data.newSongs),
            ],
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'SoundSync',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: 0,
                  ),
            ),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: onSearch,
            icon: const Icon(Icons.search),
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
    final visible = banners.take(5).toList();
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          height: 132,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(20),
          child: Text(
            'MuseHub',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Trending Now',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.92),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final banner = visible[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 8, 8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverArt(url: banner.imageUrl, borderRadius: 14),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xDD131312)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FEATURED PLAYLIST',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            banner.title == 'Featured'
                                ? 'Neon Nights Vol. 4'
                                : banner.title,
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
                            'A cinematic mix for late night listening.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: playlists.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.74,
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
                child:
                    CoverArt(url: widget.playlist.coverUrl, borderRadius: 14),
              ),
              if (_loading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black38,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.playlist.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                  letterSpacing: 0,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatPlayCount(widget.playlist.playCount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
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
