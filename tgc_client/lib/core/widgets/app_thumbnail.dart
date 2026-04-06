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
    this.size = 50.0,
    this.borderRadius = 6.0,
  });

  final String? imageUrl;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: imageUrl != null
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
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

    if (imageUrl == null) return thumbnail;

    return GestureDetector(
      onTap: () => _showFullImage(context),
      child: thumbnail,
    );
  }

  void _showFullImage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
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
