import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/models/song.dart';
import '../../core/services/music_api.dart';
import '../../core/widgets/song_tile.dart';
import '../../l10n/app_strings.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<String> _suggestions = [];
  List<Song> _songs = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final songs = await context.read<MusicApi>().searchSongs(trimmed);
      setState(() => _songs = songs);
    } catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadSuggestions(String keyword) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      if (keyword.trim().isEmpty) {
        setState(() => _suggestions = []);
        return;
      }
      final suggestions =
          await context.read<MusicApi>().searchSuggestions(keyword);
      if (mounted) setState(() => _suggestions = suggestions);
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(0, topPad + 8, 0, 160),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            strings.search,
            style: GoogleFonts.sora(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -0.8,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            controller: _controller,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 14,
              color: scheme.onSurface,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search_rounded,
                  color: scheme.onSurfaceVariant, size: 20),
              hintText: strings.searchHint,
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: scheme.onSurfaceVariant),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _suggestions = [];
                          _songs = [];
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (v) {
              setState(() {});
              _loadSuggestions(v);
            },
            onSubmitted: _search,
          ),
        ),
        if (_suggestions.isNotEmpty && _songs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in _suggestions)
                  ActionChip(
                    label: Text(
                      suggestion,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 12,
                        color: scheme.onSurface,
                      ),
                    ),
                    backgroundColor: scheme.surfaceContainerHigh,
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    onPressed: () {
                      _controller.text = suggestion;
                      _search(suggestion);
                    },
                  ),
              ],
            ),
          ),
        if (_loading)
          LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primaryContainer),
            minHeight: 2,
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _error!,
              style:
                  GoogleFonts.hankenGrotesk(fontSize: 13, color: scheme.error),
            ),
          ),
        if (_songs.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
            child: Column(
              children: [
                Icon(Icons.music_note_outlined,
                    size: 40, color: scheme.onSurfaceVariant),
                const SizedBox(height: 12),
                Text(
                  strings.searchForMusic,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sora(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  strings.searchEmptyBody,
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
        for (final song in _songs) SongTile(song: song, queue: _songs),
      ],
    );
  }
}
