import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A square network image with a graceful placeholder/error fallback.
/// Generic and reusable across all features.
///
/// Usage:
/// ```dart
/// AppThumbnail(imageUrl: product.imageUrl, size: 48)
/// ```
class AppThumbnail extends StatelessWidget {
  const AppThumbnail({
    super.key,
    this.imageUrl,
    this.thumbUrl,
    this.size = 50.0,
    this.borderRadius = 6.0,
    this.decodeWidth,
  });

  /// The full photo, opened when the thumbnail is tapped.
  final String? imageUrl;

  /// A small copy of [imageUrl] made by the server for list screens. Shown
  /// in place of [imageUrl] when given; the full photo still opens on tap.
  final String? thumbUrl;
  final double size;
  final double borderRadius;

  /// Width in device pixels to decode the photo at. Defaults to ~[size]; pass
  /// [cacheWidthFor] of the real box when a parent stretches the thumbnail.
  final int? decodeWidth;

  /// Decode width for a box of [w]×[h] logical pixels: the photos are phone
  /// shots several thousand pixels wide, and decoding them at full size is
  /// what makes a grid of them slow. Rounded up to a 64 px step so a window
  /// resize doesn't create a new cache entry for every pixel.
  static int cacheWidthFor(double w, double h, double devicePixelRatio) {
    final px = (w > h ? w : h) * devicePixelRatio;
    return ((px / 64).ceil() * 64).clamp(64, 2048);
  }

  @override
  Widget build(BuildContext context) {
    final shownUrl = thumbUrl ?? imageUrl;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: shownUrl != null
          ? CachedNetworkImage(
              imageUrl: shownUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // 1.5× headroom: a landscape photo covering a square box is
              // sized by its height, so it needs more width than the box.
              memCacheWidth:
                  decodeWidth ?? cacheWidthFor(size * 1.5, size * 1.5, dpr),
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (_, __) => Center(
                child: SizedBox(
                  width: size * 0.5,
                  height: size * 0.5,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (_, __, ___) => _Placeholder(size: size),
            )
          : _Placeholder(size: size),
    );

    if (shownUrl == null) return thumbnail;

    return GestureDetector(
      onTap: () => _showFullImage(context, shownUrl),
      child: thumbnail,
    );
  }

  void _showFullImage(BuildContext context, String shownUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: CachedNetworkImage(
            imageUrl: imageUrl ?? shownUrl,
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        size: size * 0.45,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
