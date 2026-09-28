import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/models/song.dart';
import '../../core/widgets/cover_art.dart';
import '../../l10n/app_strings.dart';

/// Pick several songs from a list and download them in one go.
///
/// Kept as its own screen rather than a selection mode bolted onto every
/// song list: any page that already has a list of songs can open this with
/// one button, and the selection/progress logic lives in exactly one place.
class BatchDownloadPage extends StatefulWidget {
  const BatchDownloadPage({required this.songs, super.key});

  final List<Song> songs;

  @override
  State<BatchDownloadPage> createState() => _BatchDownloadPageState();
}

class _BatchDownloadPageState extends State<BatchDownloadPage> {
  final Set<int> _selected = {};
  bool _downloading = false;
  int _done = 0;
  int _total = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final appState = context.watch<AppState>();

    // Songs already on disk can't be selected — showing them greyed out is
    // more useful than hiding them, since it answers "did I already get
    // this one?" without leaving the screen.
    final pending =
        widget.songs.where((song) => !appState.isDownloaded(song)).toList();
    final allSelected =
        pending.isNotEmpty && _selected.length == pending.length;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Text(
          _selected.isEmpty
              ? strings.selectSongs
              : strings.selectedCount(_selected.length),
          style: GoogleFonts.sora(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
        actions: [
          if (pending.isNotEmpty && !_downloading)
            TextButton(
              onPressed: () => setState(() {
                if (allSelected) {
                  _selected.clear();
                } else {
                  _selected
                    ..clear()
                    ..addAll(pending.map((song) => song.id));
                }
              }),
              child: Text(
                allSelected ? strings.clearSelection : strings.selectAll,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.primaryContainer,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_downloading)
            LinearProgressIndicator(
              value: _total == 0 ? null : _done / _total,
              backgroundColor: Colors.transparent,
              valueColor:
                  AlwaysStoppedAnimation<Color>(scheme.primaryContainer),
              minHeight: 2,
            ),
          Expanded(
            child: pending.isEmpty
                ? _AllDownloaded(strings: strings, scheme: scheme)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: widget.songs.length,
                    itemBuilder: (_, i) {
                      final song = widget.songs[i];
                      final already = appState.isDownloaded(song);
                      return _SelectableSongRow(
                        song: song,
                        alreadyDownloaded: already,
                        selected: _selected.contains(song.id),
                        enabled: !already && !_downloading,
                        onToggle: () => setState(() {
                          if (!_selected.add(song.id)) {
                            _selected.remove(song.id);
                          }
                        }),
                      );
                    },
                  ),
          ),
          _BottomBar(
            strings: strings,
            scheme: scheme,
            downloading: _downloading,
            done: _done,
            total: _total,
            selectedCount: _selected.length,
            onDownload: _runBatchDownload,
          ),
        ],
      ),
    );
  }

  Future<void> _runBatchDownload() async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final appState = context.read<AppState>();

    final targets =
        widget.songs.where((song) => _selected.contains(song.id)).toList();
    if (targets.isEmpty) return;

    setState(() {
      _downloading = true;
      _done = 0;
      _total = targets.length;
    });

    final result = await appState.downloadSongs(
      targets,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _done = done;
          _total = total;
        });
      },
    );

    if (!mounted) return;
    setState(() => _downloading = false);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.failed == 0
              ? strings.batchDownloadDone(result.succeeded)
              : strings.batchDownloadPartial(result.succeeded, result.failed),
        ),
      ),
    );
    navigator.pop();
  }
}

class _SelectableSongRow extends StatelessWidget {
  const _SelectableSongRow({
    required this.song,
    required this.alreadyDownloaded,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final Song song;
  final bool alreadyDownloaded;
  final bool selected;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onToggle : null,
        child: Opacity(
          opacity: alreadyDownloaded ? 0.45 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: alreadyDownloaded
                      ? Icon(
                          Icons.check_circle_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        )
                      : Checkbox(
                          value: selected,
                          onChanged: enabled ? (_) => onToggle() : null,
                          visualDensity: VisualDensity.compact,
                        ),
                ),
                const SizedBox(width: 8),
                CoverArt(url: song.coverUrl, size: 44, borderRadius: 8),
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
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        alreadyDownloaded
                            ? strings.alreadyDownloaded
                            : song.artistText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.strings,
    required this.scheme,
    required this.downloading,
    required this.done,
    required this.total,
    required this.selectedCount,
    required this.onDownload,
  });

  final AppStrings strings;
  final ColorScheme scheme;
  final bool downloading;
  final int done;
  final int total;
  final int selectedCount;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed:
                downloading || selectedCount == 0 ? null : () => onDownload(),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              downloading
                  ? strings.downloadingProgress(done, total)
                  : strings.downloadSelected(selectedCount),
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AllDownloaded extends StatelessWidget {
  const _AllDownloaded({required this.strings, required this.scheme});

  final AppStrings strings;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.download_done_rounded,
              size: 36,
              color: scheme.primaryContainer,
            ),
            const SizedBox(height: 16),
            Text(
              strings.nothingToDownload,
              textAlign: TextAlign.center,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
