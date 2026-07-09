import 'package:flutter_test/flutter_test.dart';
import 'package:musehub/core/models/song.dart';
import 'package:musehub/core/services/music_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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

  test('Song.fromJson builds Netease artwork URL from album picId', () {
    final song = Song.fromJson({
      'id': 17177324,
      'name': 'Yellow',
      'artists': [
        {'id': 89365, 'name': 'Coldplay'},
      ],
      'album': {
        'name': 'Yellow',
        'picId': 109951167815599264,
      },
      'duration': 266773,
    });

    expect(
      song.coverUrl,
      'https://p2.music.126.net/n6BatGZdnRaEnIC0h7kVOg==/'
      '109951167815599264.jpg?param=300y300',
    );
  });

  test('MusicApi auto-discovers resolver when no resolver URL is configured',
      () async {
    final requests = <Uri>[];
    final api = MusicApi(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/song/url/v1' ||
            request.url.path == '/song/url') {
          return http.Response('{"data":[{"url":null}]}', 200);
        }
        if (request.url.path == '/unblock-music') {
          return http.Response(
            '{"url":"https://example.com/audio.mp3","source":"kuwo"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'HEAD') {
          return http.Response(
            '',
            200,
            headers: {
              'content-type': 'audio/mpeg',
              'content-length': '2097152',
            },
          );
        }
        return http.Response('not found', 404);
      }),
    )..discoverResolverBaseUrl = () async => 'http://192.168.43.154:30489';

    final resolved = await api.resolveAudioSource(
      const Song(
        id: 1315445072,
        name: 'Always Remember Us This Way',
        artists: [],
        album: '',
        coverUrl: '',
        durationMs: 210000,
      ),
    );

    expect(resolved?.method, ResolveMethod.alger);
    expect(resolved?.source, 'kuwo');
    expect(api.resolverBaseUrl, 'http://192.168.43.154:30489');
    expect(requests.any((uri) => uri.host == '192.168.43.154'), isTrue);
  });

  test('MusicApi rediscoveres resolver when the stored LAN URL is stale',
      () async {
    final requests = <Uri>[];
    final api = MusicApi(
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.host == '192.168.1.20') {
          throw http.ClientException('old resolver unreachable', request.url);
        }
        if (request.url.path == '/song/url/v1' ||
            request.url.path == '/song/url') {
          return http.Response('{"data":[{"url":null}]}', 200);
        }
        if (request.url.path == '/unblock-music') {
          return http.Response(
            '{"url":"https://example.com/audio.mp3","source":"migu"}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'HEAD') {
          return http.Response(
            '',
            200,
            headers: {
              'content-type': 'audio/mpeg',
              'content-length': '2097152',
            },
          );
        }
        return http.Response('not found', 404);
      }),
    )
      ..resolverBaseUrl = 'http://192.168.1.20:30489'
      ..discoverResolverBaseUrl = () async => 'http://192.168.43.154:30489';

    final resolved = await api.resolveAudioSource(
      const Song(
        id: 1315445072,
        name: 'Always Remember Us This Way',
        artists: [],
        album: '',
        coverUrl: '',
        durationMs: 210000,
      ),
    );

    expect(resolved?.method, ResolveMethod.alger);
    expect(resolved?.source, 'migu');
    expect(api.resolverBaseUrl, 'http://192.168.43.154:30489');
    expect(requests.any((uri) => uri.host == '192.168.1.20'), isTrue);
    expect(requests.any((uri) => uri.host == '192.168.43.154'), isTrue);
  });
}
