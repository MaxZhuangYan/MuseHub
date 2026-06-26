import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/song.dart';
import '../../core/services/music_api.dart';
import '../../core/widgets/song_tile.dart';

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
      final suggestions = await context.read<MusicApi>().searchSuggestions(keyword);
      if (mounted) setState(() => _suggestions = suggestions);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: SearchBar(
            controller: _controller,
            leading: const Icon(Icons.search),
            hintText: 'Search songs, artists, albums',
            onChanged: _loadSuggestions,
            onSubmitted: _search,
            trailing: [
              if (_controller.text.isNotEmpty)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _suggestions = [];
                      _songs = [];
                    });
                  },
                ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty && _songs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in _suggestions)
                  ActionChip(
                    label: Text(suggestion),
                    onPressed: () {
                      _controller.text = suggestion;
                      _search(suggestion);
                    },
                  ),
              ],
            ),
          ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_songs.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Search for music to build a mobile queue.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        for (final song in _songs) SongTile(song: song, queue: _songs),
      ],
    );
  }
}
