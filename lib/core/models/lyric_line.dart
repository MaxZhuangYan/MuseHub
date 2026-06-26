class LyricLine {
  const LyricLine({
    required this.time,
    required this.text,
  });

  final Duration time;
  final String text;
}

List<LyricLine> parseLrc(String raw) {
  final lines = <LyricLine>[];
  final regex = RegExp(r'\[(\d{1,2}):(\d{1,2})(?:\.(\d{1,3}))?\](.*)');

  for (final line in raw.split('\n')) {
    final match = regex.firstMatch(line.trim());
    if (match == null) continue;
    final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
    final millisRaw = match.group(3) ?? '0';
    final millis = int.tryParse(millisRaw.padRight(3, '0').substring(0, 3)) ?? 0;
    final text = (match.group(4) ?? '').trim();
    if (text.isEmpty) continue;
    lines.add(
      LyricLine(
        time: Duration(minutes: minutes, seconds: seconds, milliseconds: millis),
        text: text,
      ),
    );
  }

  lines.sort((a, b) => a.time.compareTo(b.time));
  return lines;
}
