import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/services/music_api.dart';
import 'core/theme.dart';
import 'core/widgets/cover_art.dart';
import 'features/home/home_page.dart';
import 'features/library/library_page.dart';
import 'features/player/full_player_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/settings_page.dart';
import 'player/player_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = MusicApi();
  runApp(MuseHubApp(api: api));
}

class MuseHubApp extends StatelessWidget {
  const MuseHubApp({required this.api, super.key});

  final MusicApi api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MusicApi>.value(value: api),
        ChangeNotifierProvider(create: (_) => AppState(api)..load()),
        ChangeNotifierProvider(create: (_) => PlayerController(api)),
      ],
      child: MaterialApp(
        title: 'MuseHub',
        debugShowCheckedModeBanner: false,
        theme: MuseTheme.light(),
        darkTheme: MuseTheme.dark(),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    HomePage(),
    SearchPage(),
    LibraryPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MuseHub'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _index = 1),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _pages[_index]),
          const Positioned(left: 0, right: 0, bottom: 0, child: MiniPlayer()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Library',
          ),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerController>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const FullPlayerPage()),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(
              children: [
                CoverArt(url: song.coverUrl, size: 44, borderRadius: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(
                        player.activeLyric?.text ?? song.artistText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (player.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else
                  IconButton(
                    tooltip: player.isPlaying ? 'Pause' : 'Play',
                    icon: Icon(player.isPlaying ? Icons.pause_circle : Icons.play_circle),
                    onPressed: player.toggle,
                  ),
                IconButton(
                  tooltip: 'Next',
                  icon: const Icon(Icons.skip_next),
                  onPressed: player.next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
