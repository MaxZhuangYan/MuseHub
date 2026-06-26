import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/home_snapshot.dart';
import '../../core/models/playlist.dart';
import '../../core/models/song.dart';
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
        if (state.connectionState == ConnectionState.waiting && !state.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.hasError) {
          return _ErrorState(message: '${state.error}', onRetry: _refresh);
        }

        final data = state.data ?? const HomeSnapshot(banners: [], newSongs: [], playlists: []);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              _HeroBanners(banners: data.banners),
              SectionHeader(
                title: 'New music',
                action: FilledButton.tonalIcon(
                  onPressed: data.newSongs.isEmpty
                      ? null
                      : () => context.read<PlayerController>().playSong(
                            data.newSongs.first,
                            queue: data.newSongs,
                          ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                ),
              ),
              for (final song in data.newSongs.take(8)) SongTile(song: song, queue: data.newSongs),
              const SectionHeader(title: 'Recommended playlists'),
              SizedBox(
                height: 190,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: data.playlists.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => _PlaylistCard(playlist: data.playlists[index]),
                ),
              ),
            ],
          ),
        );
      },
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
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return SizedBox(
      height: 168,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.9),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final banner = visible[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 8, 8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverArt(url: banner.imageUrl, borderRadius: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Text(
                    banner.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
    return SizedBox(
      width: 132,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _loading
            ? null
            : () async {
                setState(() => _loading = true);
                try {
                  final songs = await context.read<MusicApi>().playlistSongs(widget.playlist.id);
                  if (songs.isNotEmpty && context.mounted) {
                    await context.read<PlayerController>().playSong(songs.first, queue: songs);
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
                CoverArt(url: widget.playlist.coverUrl, size: 132),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
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
