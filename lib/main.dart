import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/services/musehub_server_api.dart';
import 'core/services/music_api.dart';
import 'core/theme.dart';
import 'core/widgets/cover_art.dart';
import 'features/home/home_page.dart';
import 'features/library/library_page.dart';
import 'features/player/full_player_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/settings_page.dart';
import 'l10n/app_strings.dart';
import 'player/player_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = MusicApi();
  final serverApi = MuseHubServerApi();
  runApp(MuseHubApp(api: api, serverApi: serverApi));
}

class MuseHubApp extends StatelessWidget {
  const MuseHubApp({
    required this.api,
    required this.serverApi,
    super.key,
  });

  final MusicApi api;
  final MuseHubServerApi serverApi;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<MusicApi>.value(value: api),
        Provider<MuseHubServerApi>.value(value: serverApi),
        ChangeNotifierProvider(create: (_) => AppState(api, serverApi)..load()),
        ChangeNotifierProvider(create: (_) => PlayerController(api)),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) => MaterialApp(
          title: 'MuseHub',
          debugShowCheckedModeBanner: false,
          locale: appState.locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: MuseTheme.light(),
          darkTheme: MuseTheme.dark(),
          home: const AppShell(),
        ),
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(child: _pages[_index]),
          Positioned(
            left: 0,
            right: 0,
            bottom: 76 + bottomInset,
            child: const MiniPlayer(),
          ),
        ],
      ),
      bottomNavigationBar: _GlassNavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: MuseTheme.bg.withValues(alpha: 0.80),
            border: Border(
              top: BorderSide(
                color: scheme.onSurface.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: onChanged,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: strings.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.search_outlined),
                selectedIcon: const Icon(Icons.search),
                label: strings.search,
              ),
              NavigationDestination(
                icon: const Icon(Icons.library_music_outlined),
                selectedIcon: const Icon(Icons.library_music),
                label: strings.library,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: strings.settings,
              ),
            ],
          ),
        ),
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

    final strings = AppStrings.of(context);
    final accent = player.ambientColor ?? MuseTheme.accent;
    final progress = player.duration.inMilliseconds == 0
        ? 0.0
        : (player.position.inMilliseconds / player.duration.inMilliseconds)
            .clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: MuseTheme.surface2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thin ambient-tinted progress line
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                minHeight: 2,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FullPlayerPage(),
                          ),
                        ),
                        child: Row(
                          children: [
                            Hero(
                              tag: 'miniplayer_cover',
                              child: CoverArt(
                                url: song.coverUrl,
                                size: 44,
                                borderRadius: 10,
                              ),
                            ),
                            const SizedBox(width: 12),
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
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: MuseTheme.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    player.activeLyric?.text ?? song.artistText,
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
                          ],
                        ),
                      ),
                    ),
                    if (player.isLoading && !player.isPlaying)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      IconButton(
                        tooltip:
                            player.isPlaying ? strings.pause : strings.play,
                        icon: Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: MuseTheme.textPrimary,
                          size: 30,
                        ),
                        onPressed: player.toggle,
                      ),
                    IconButton(
                      tooltip: strings.next,
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: MuseTheme.textSecondary,
                        size: 26,
                      ),
                      onPressed: player.next,
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
