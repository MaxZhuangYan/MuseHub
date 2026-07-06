import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CoverArt extends StatelessWidget {
  const CoverArt({
    required this.url,
    this.size,
    this.borderRadius = 8,
    super.key,
  });

  final String url;
  final double? size;
  final double borderRadius;
  static const _imageHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Referer': 'https://music.163.com/',
  };

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final placeholder = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surfaceContainer,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Theme.of(context)
              .colorScheme
              .onSurfaceVariant
              .withValues(alpha: 0.72),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                httpHeaders: _imageHeaders,
                fit: BoxFit.cover,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}
