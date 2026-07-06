import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:musehub/core/app_state.dart';
import 'package:musehub/core/models/artist.dart';
import 'package:musehub/core/models/song.dart';
import 'package:musehub/core/services/music_api.dart';
import 'package:musehub/features/player/full_player_page.dart';
import 'package:musehub/l10n/app_strings.dart';
import 'package:musehub/main.dart';
import 'package:musehub/player/player_controller.dart';

void main() {
  testWidgets('renders the MuseHub app shell', (tester) async {
    await tester.pumpWidget(MuseHubApp(api: MusicApi()));
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('full player controls fit a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = MusicApi();
    final player = _FakePlayerController();
    addTearDown(player.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<MusicApi>.value(value: api),
          ChangeNotifierProvider<AppState>.value(value: AppState(api)),
          ChangeNotifierProvider<PlayerController>.value(value: player),
        ],
        child: const MaterialApp(
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          home: FullPlayerPage(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

class _FakePlayerController extends PlayerController {
  _FakePlayerController() : super(MusicApi());

  final _song = const Song(
    id: 19292984,
    name: 'Love Story',
    artists: [Artist(id: 44266, name: 'Taylor Swift')],
    album: 'Fearless',
    coverUrl: '',
    durationMs: 215000,
  );

  @override
  Song? get current => _song;

  @override
  List<Song> get queue => [_song];

  @override
  Duration get position => const Duration(seconds: 5);

  @override
  Duration get duration => const Duration(minutes: 3, seconds: 35);

  @override
  bool get isPlaying => true;

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  PlaybackRepeatMode get repeatMode => PlaybackRepeatMode.all;

  @override
  Future<void> toggle() async {}

  @override
  Future<void> next({bool automatic = false}) async {}

  @override
  Future<void> previous() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  void cycleRepeatMode() {}
}
