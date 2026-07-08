import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/home_snapshot.dart';
import '../../core/models/playlist.dart';
import '../../core/services/music_api.dart';
import '../../core/theme.dart';
import '../../core/widgets/cover_art.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/song_tile.dart';
import '../../l10n/app_strings.dart';
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
    final strings = AppStrings.of(context);
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
            padding: EdgeInsets.fromLTRB(0, topPad + 8, 0, 170),
            children: [
              const _HomeHeader(),
              const SizedBox(height: 8),
              if (data.banners.isNotEmpty) ...[
                SectionHeader(title: strings.trendingNow),
                _FeaturedBanner(banner: data.banners.first),
              ],
              SectionHeader(
                title: strings.madeForYou,
                action: data.playlists.isEmpty
                    ? null
                    : _SeeAllButton(
                        label: strings.playAll,
                        onPressed: () async {
                          final songs = await context
                              .read<MusicApi>()
                              .playlistSongs(data.playlists.first.id);
                          if (songs.isNotEmpty && context.mounted) {
                            await context
                                .read<PlayerController>()
                                .playSong(songs.first, queue: songs);
                          }
                        },
                      ),
              ),
              _PlaylistGrid(playlists: data.playlists.take(6).toList()),
              SectionHeader(title: strings.newReleases),
              for (final song in data.newSongs.take(10))
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
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.of(context).goodMusic,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    color: MuseTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  AppStrings.of(context).appName,
                  style: GoogleFonts.sora(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: MuseTheme.textPrimary,
                    letterSpacing: -1.0,
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

/// Full-width featured banner (Trending Now).
class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({required this.banner});

  final BannerItem banner;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CoverArt(url: banner.imageUrl, borderRadius: 0),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.35, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.featuredPlaylist,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: MuseTheme.accent,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      banner.title == 'Featured'
                          ? strings.fallbackBannerTitle
                          : banner.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.cinematicMix,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: MuseTheme.accent,
        textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 13, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      icon: const Icon(Icons.play_arrow_rounded, size: 16),
      label: Text(label),
    );
  }
}

/// Two-column playlist grid (Made For You).
class _PlaylistGrid extends StatelessWidget {
  const _PlaylistGrid({required this.playlists});
  final List<MusicPlaylist> playlists;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 18,
        crossAxisSpacing: 16,
        childAspectRatio: 0.80,
        children: [
          for (final playlist in playlists) _PlaylistCard(playlist: playlist),
        ],
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
  bool _pressed = false;

  Future<void> _play() async {
    setState(() => _loading = true);
    try {
      final songs =
          await context.read<MusicApi>().playlistSongs(widget.playlist.id);
      if (songs.isNotEmpty && mounted) {
        // ignore: use_build_context_synchronously
        await context
            .read<PlayerController>()
            .playSong(songs.first, queue: songs);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _loading ? null : _play,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverArt(url: widget.playlist.coverUrl, borderRadius: 0),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.55, 1.0],
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _loading
                          ? const SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: MuseTheme.accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: MuseTheme.accent
                                        .withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 20),
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.playlist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MuseTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              strings.playCount(widget.playlist.playCount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12,
                color: MuseTheme.textSecondary,
              ),
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
              label: Text(AppStrings.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
