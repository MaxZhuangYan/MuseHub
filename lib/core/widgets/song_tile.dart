import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../player/player_controller.dart';
import '../app_state.dart';
import '../../l10n/app_strings.dart';
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
    final player = context.watch<PlayerController>();
    final isFavorite = appState.isFavorite(song);
    final isPlaying = player.current?.id == song.id;
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            context.read<PlayerController>().playSong(song, queue: queue),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              // Cover art with now-playing overlay
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child:
                          CoverArt(url: song.coverUrl, size: 54, borderRadius: 0),
                    ),
                    if (isPlaying)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.38),
                          ),
                          child: Center(
                            child: _EqualizerIcon(
                              color: scheme.primaryContainer,
                              isPlaying: player.isPlaying,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
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
                        color: isPlaying
                            ? scheme.primaryContainer
                            : scheme.onSurface,
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
                    tooltip: isFavorite
                        ? strings.removeFavorite
                        : strings.moreOptions,
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

/// Animated three-bar equalizer icon shown on currently playing tracks.
class _EqualizerIcon extends StatefulWidget {
  const _EqualizerIcon({required this.color, required this.isPlaying});
  final Color color;
  final bool isPlaying;

  @override
  State<_EqualizerIcon> createState() => _EqualizerIconState();
}

class _EqualizerIconState extends State<_EqualizerIcon>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    final durations = [600, 450, 520];
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: durations[i]),
      ),
    );
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0.25, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    if (widget.isPlaying) _startAll();
  }

  void _startAll() {
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 80), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  void _stopAll() {
    for (final c in _controllers) {
      c.animateTo(0.25);
    }
  }

  @override
  void didUpdateWidget(_EqualizerIcon old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying != old.isPlaying) {
      widget.isPlaying ? _startAll() : _stopAll();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 3,
              height: 14 * _animations[i].value,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }),
    );
  }
}
