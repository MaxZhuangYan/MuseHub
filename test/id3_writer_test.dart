import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:musehub/core/services/id3_writer.dart';

/// Fake MPEG audio: a frame-sync header followed by filler.
final _audio = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x64, ...List.filled(64, 7)]);

Uint8List _id3v24({required int bodySize, bool footer = false}) {
  return Uint8List.fromList([
    0x49, 0x44, 0x33, 0x04, 0x00, footer ? 0x10 : 0x00,
    (bodySize >> 21) & 0x7F,
    (bodySize >> 14) & 0x7F,
    (bodySize >> 7) & 0x7F,
    bodySize & 0x7F,
    ...List.filled(bodySize, 0),
    if (footer) ...List.filled(10, 0),
  ]);
}

void main() {
  test('audio after the tag is byte-identical', () {
    final out = Id3Writer.retag(_audio, title: 'Song');
    expect(out.sublist(Id3Writer.audioStart(out)), _audio);
  });

  test('an existing v2.4 tag is replaced, not stacked', () {
    final tagged = Uint8List.fromList([..._id3v24(bodySize: 35), ..._audio]);
    final out = Id3Writer.retag(tagged, title: 'Song');
    expect(out.sublist(Id3Writer.audioStart(out)), _audio);
    // Exactly one "ID3" header left.
    expect(out[3], 0x03);
    expect(String.fromCharCodes(out.sublist(Id3Writer.audioStart(out), Id3Writer.audioStart(out) + 3)),
        isNot('ID3'));
  });

  test('a v2.4 footer is skipped too', () {
    final tagged = Uint8List.fromList([
      ..._id3v24(bodySize: 20, footer: true),
      ..._audio,
    ]);
    expect(Id3Writer.audioStart(tagged), 10 + 20 + 10);
  });

  test('untagged input starts at 0', () {
    expect(Id3Writer.audioStart(_audio), 0);
  });

  test('Chinese text is written as UTF-16 with a BOM', () {
    final out = Id3Writer.retag(_audio, title: '海阔天空', artist: 'Beyond');
    final bytes = out.toList();
    final tit2 = _indexOf(bytes, 'TIT2'.codeUnits);
    expect(tit2, greaterThan(0));
    // frame header is 10 bytes; payload starts with encoding 0x01 + FF FE
    expect(bytes.sublist(tit2 + 10, tit2 + 13), [0x01, 0xFF, 0xFE]);
    // "海" is U+6D77 -> little-endian 77 6D
    expect(bytes.sublist(tit2 + 13, tit2 + 15), [0x77, 0x6D]);
  });

  test('empty fields and non-image covers are omitted', () {
    final out = Id3Writer.retag(
      _audio,
      title: 'Song',
      album: '  ',
      cover: Uint8List.fromList([1, 2, 3, 4]),
    );
    final bytes = out.toList();
    expect(_indexOf(bytes, 'TALB'.codeUnits), -1);
    expect(_indexOf(bytes, 'APIC'.codeUnits), -1);
  });

  test('a JPEG cover is embedded', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(32, 1)]);
    final out = Id3Writer.retag(_audio, title: 'Song', cover: jpeg);
    final bytes = out.toList();
    expect(_indexOf(bytes, 'APIC'.codeUnits), greaterThan(0));
    expect(_indexOf(bytes, 'image/jpeg'.codeUnits), greaterThan(0));
  });
}

int _indexOf(List<int> haystack, List<int> needle) {
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }
  return -1;
}
