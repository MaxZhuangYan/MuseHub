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

    final bool hasResults = _songs.isNotEmpty;
    final bool isEmpty = _songs.isEmpty && !_loading && _error == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Page title ──
        SizedBox(height: topPad + 8),
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

        // ── Search field ──
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
                          _error = null;
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

        // ── Suggestion chips ──
        if (_suggestions.isNotEmpty && !hasResults)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                    side: BorderSide.none,
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

        // ── Loading bar ──
        if (_loading)
          LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            valueColor:
                AlwaysStoppedAnimation<Color>(scheme.primaryContainer),
            minHeight: 2,
          ),

        // ── Error ──
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              _error!,
              style: GoogleFonts.hankenGrotesk(
                  fontSize: 13, color: scheme.error),
            ),
          ),

        // ── Content area ──
        Expanded(
          child: hasResults
              ? ListView.builder(
                  padding: const EdgeInsets.only(bottom: 160),
                  itemCount: _songs.length,
                  itemBuilder: (_, i) =>
                      SongTile(song: _songs[i], queue: _songs),
                )
              : isEmpty
                  ? _EmptyState(hasQuery: _controller.text.trim().isNotEmpty)
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.primaryContainer.withValues(alpha: 0.20),
                ),
              ),
              child: Icon(
                hasQuery
                    ? Icons.search_off_rounded
                    : Icons.music_note_rounded,
                size: 30,
                color: scheme.primaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? strings.noResults : strings.searchForMusic,
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
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
    );
  }
}
