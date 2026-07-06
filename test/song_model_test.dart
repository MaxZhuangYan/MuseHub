import 'package:flutter_test/flutter_test.dart';
import 'package:musehub/core/models/song.dart';

void main() {
  test('Song.fromJson reads nested Netease detail artwork', () {
    final song = Song.fromJson({
      'song': {
        'id': '17177324',
        'name': 'Yellow',
        'ar': [
          {'id': 89365, 'name': 'Coldplay'},
        ],
        'al': {
          'name': 'Parachutes',
          'blurPicUrl': 'http://p1.music.126.net/yellow.jpg',
        },
        'dt': 269000,
      },
    });

    expect(song.id, 17177324);
    expect(song.name, 'Yellow');
    expect(song.artistText, 'Coldplay');
    expect(song.album, 'Parachutes');
    expect(song.coverUrl, 'https://p1.music.126.net/yellow.jpg');
    expect(song.durationMs, 269000);
  });

  test('Song.mergeDetails preserves existing fields and fills missing artwork',
      () {
    const base = Song(
      id: 1,
      name: 'Base',
      artists: [],
      album: '',
      coverUrl: '',
    );
    final details = Song.fromJson({
      'id': 1,
      'name': 'Detailed',
      'ar': [
        {'id': 2, 'name': 'Artist'},
      ],
      'al': {
        'name': 'Album',
        'picUrl': 'https://p1.music.126.net/detail.jpg',
      },
      'dt': 180000,
    });

    final merged = base.mergeDetails(details);

    expect(merged.name, 'Detailed');
    expect(merged.artistText, 'Artist');
    expect(merged.album, 'Album');
    expect(merged.coverUrl, 'https://p1.music.126.net/detail.jpg');
    expect(merged.durationMs, 180000);
  });
}
