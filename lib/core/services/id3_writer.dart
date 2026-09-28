import 'dart:convert';
import 'dart:typed_data';

/// Writes an ID3v2.3 tag (title / artist / album / cover) onto MP3 bytes.
///
/// Files from Netease's CDN mostly ship with an empty ID3 header — measured
/// on 40 downloads, only one carried a title — so without this a downloaded
/// song shows up nameless in Finder, the Files app and every other player.
/// v2.3 rather than v2.4 because it is what Windows Explorer, older car
/// stereos and most Android media scanners actually read.
class Id3Writer {
  const Id3Writer._();

  /// Returns [audio] with any existing ID3v2 tag replaced by a fresh one.
  /// Frames whose value is empty are simply omitted.
  static Uint8List retag(
    Uint8List audio, {
    required String title,
    String artist = '',
    String album = '',
    Uint8List? cover,
  }) {
    final frames = BytesBuilder(copy: false);
    void addText(String id, String value) {
      if (value.trim().isEmpty) return;
      frames.add(_frame(id, _utf16Text(value.trim())));
    }

    addText('TIT2', title);
    addText('TPE1', artist);
    addText('TALB', album);
    if (cover != null && cover.isNotEmpty) {
      final mime = _imageMime(cover);
      if (mime != null) frames.add(_frame('APIC', _picture(mime, cover)));
    }

    final body = frames.takeBytes();
    final header = <int>[
      0x49, 0x44, 0x33, // "ID3"
      0x03, 0x00, // version 2.3.0
      0x00, // flags
      ..._syncSafe(body.length),
    ];
    return Uint8List.fromList([
      ...header,
      ...body,
      ...audio.sublist(audioStart(audio)),
    ]);
  }

  /// Offset where the audio begins, i.e. just past any existing ID3v2 tag.
  static int audioStart(Uint8List bytes) {
    if (bytes.length < 10 ||
        bytes[0] != 0x49 ||
        bytes[1] != 0x44 ||
        bytes[2] != 0x33) {
      return 0;
    }
    final version = bytes[3];
    final flags = bytes[5];
    final size = (bytes[6] & 0x7F) << 21 |
        (bytes[7] & 0x7F) << 14 |
        (bytes[8] & 0x7F) << 7 |
        (bytes[9] & 0x7F);
    // v2.4 may carry a 10-byte footer after the tag body.
    final footer = version == 4 && (flags & 0x10) != 0 ? 10 : 0;
    final end = 10 + size + footer;
    return end <= bytes.length ? end : 0;
  }

  static List<int> _frame(String id, List<int> data) {
    final size = data.length;
    return [
      ...ascii.encode(id),
      // v2.3 frame sizes are plain big-endian, not sync-safe.
      (size >> 24) & 0xFF,
      (size >> 16) & 0xFF,
      (size >> 8) & 0xFF,
      size & 0xFF,
      0x00, 0x00, // frame flags
      ...data,
    ];
  }

  /// Text frame payload: encoding 0x01 (UTF-16 with BOM), so Chinese titles
  /// survive — Latin-1 would turn them into question marks.
  static List<int> _utf16Text(String value) {
    return [0x01, 0xFF, 0xFE, ..._utf16le(value)];
  }

  static List<int> _picture(String mime, Uint8List image) {
    return [
      0x00, // text encoding for the description: Latin-1
      ...latin1.encode(mime),
      0x00,
      0x03, // picture type: front cover
      0x00, // empty description, terminated
      ...image,
    ];
  }

  static List<int> _utf16le(String value) {
    final out = <int>[];
    for (final unit in value.codeUnits) {
      out
        ..add(unit & 0xFF)
        ..add((unit >> 8) & 0xFF);
    }
    return out;
  }

  static List<int> _syncSafe(int size) {
    return [
      (size >> 21) & 0x7F,
      (size >> 14) & 0x7F,
      (size >> 7) & 0x7F,
      size & 0x7F,
    ];
  }

  static String? _imageMime(Uint8List bytes) {
    if (bytes.length > 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    return null;
  }
}
