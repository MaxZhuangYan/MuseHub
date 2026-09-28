import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/models/song.dart';
import '../../core/services/download_service.dart';
import '../../core/services/music_api.dart';
import '../../core/widgets/song_tile.dart';
import '../../l10n/app_strings.dart';
import '../downloads/batch_download_page.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  Future<List<Song>>? _favorites;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ids = context.watch<AppState>().favoriteIds.toList();
    _favorites = context.read<MusicApi>().songDetails(ids);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final topPad = MediaQuery.paddingOf(context).top;
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    final downloads = appState.downloads;
    final favoriteIds = appState.favoriteIds;

    if (downloads.isEmpty && favoriteIds.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LibraryHeader(topPad: topPad),
          Expanded(child: _EmptyLibrary(strings: strings, scheme: scheme)),
        ],
      );
    }

    return FutureBuilder<List<Song>>(
      future: _favorites,
      builder: (context, state) {
        final favorites = state.data ?? const <Song>[];
        return ListView(
          padding: EdgeInsets.fromLTRB(0, topPad + 8, 0, 160),
          children: [
            const _LibraryHeader(topPad: 0),
            if (downloads.isNotEmpty) ...[
              _SectionHeader(
                title: strings.downloads,
                subtitle: strings.downloadedSongs(downloads.length),
                trailing: _OpenDownloadFolderButton(appState: appState),
              ),
              for (final item in downloads)
                SongTile(
                  song: item.song,
                  queue: downloads.map((download) => download.song).toList(),
                  trailing: _DownloadTrailing(item: item),
                ),
              const SizedBox(height: 16),
            ],
            if (favoriteIds.isNotEmpty) ...[
              _SectionHeader(
                title: strings.favorites,
                subtitle: strings.savedLocally(favoriteIds.length),
                trailing: favorites.isEmpty
                    ? null
                    : _BatchDownloadButton(songs: favorites),
              ),
              if (state.connectionState == ConnectionState.waiting &&
                  !state.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                for (final song in favorites) SongTile(song: song, queue: favorites),
            ],
          ],
        );
      },
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader({required this.topPad});
  final double topPad;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 12),
      child: Text(
        strings.library,
        style: GoogleFonts.sora(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
          letterSpacing: -0.8,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.sora(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: scheme.onSurface.withValues(alpha: 0.08),
          ),
        ],
      ),
    );
  }
}

class _BatchDownloadButton extends StatelessWidget {
  const _BatchDownloadButton({required this.songs});
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return IconButton(
      tooltip: strings.batchDownload,
      icon: const Icon(Icons.download_for_offline_outlined, size: 20),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BatchDownloadPage(songs: songs),
        ),
      ),
    );
  }
}

class _OpenDownloadFolderButton extends StatelessWidget {
  const _OpenDownloadFolderButton({required this.appState});
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    // Android/iOS have no reliable "reveal in file manager" intent, so
    // offering a button that always throws is worse than useless. There we
    // show the folder path instead, which is something the user can act on.
    final canOpen = appState.canOpenDownloadDirectory;
    return IconButton(
      tooltip: canOpen ? strings.openDownloadFolder : strings.downloadLocation,
      icon: Icon(
        canOpen ? Icons.folder_open_rounded : Icons.info_outline_rounded,
        size: 20,
      ),
      onPressed: () async {
        if (canOpen) {
          try {
            await appState.openDownloadDirectory();
            return;
          } on Object {
            // Fall through to showing the path — more actionable than an
            // error telling the user something didn't work.
          }
        }
        final path = await appState.downloadDirectoryPath();
        if (!context.mounted) return;
        await _showPathDialog(context, path, strings);
      },
    );
  }

  Future<void> _showPathDialog(
    BuildContext context,
    String path,
    AppStrings strings,
  ) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          strings.downloadLocation,
          style: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SelectableText(
          path,
          style: GoogleFonts.hankenGrotesk(fontSize: 12, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(dialogContext);
              await Clipboard.setData(ClipboardData(text: path));
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              messenger.showSnackBar(
                SnackBar(content: Text(strings.pathCopied)),
              );
            },
            child: Text(strings.copyPath),
          ),
        ],
      ),
    );
  }
}

class _DownloadTrailing extends StatelessWidget {
  const _DownloadTrailing({required this.item});
  final DownloadedSong item;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return IconButton(
      tooltip: strings.deleteDownload,
      icon: const Icon(Icons.delete_outline_rounded, size: 20),
      onPressed: () => context.read<AppState>().deleteDownload(item.song),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({
    required this.strings,
    required this.scheme,
  });

  final AppStrings strings;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 0, 40, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.primaryContainer.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(
                Icons.library_music_outlined,
                size: 30,
                color: scheme.primaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              strings.yourFavorites,
              style: GoogleFonts.sora(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${strings.favoritesEmpty}\n${strings.downloadsEmpty}',
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
