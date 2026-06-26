import 'package:flutter_test/flutter_test.dart';
import 'package:musehub/core/services/music_api.dart';
import 'package:musehub/main.dart';

void main() {
  testWidgets('renders the MuseHub app shell', (tester) async {
    await tester.pumpWidget(MuseHubApp(api: MusicApi()));
    await tester.pump();

    expect(find.text('MuseHub'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
  });
}
