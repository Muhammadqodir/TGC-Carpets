import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Renders a Flutter widget into a PNG image file.
///
/// Uses [RepaintBoundary] + [RenderRepaintBoundary] to capture
/// the widget as a raster image, then encodes it to PNG and
/// saves it to a temporary file.
class LabelRenderer {
  /// The global key attached to the [RepaintBoundary] wrapping the label.
  final GlobalKey repaintBoundaryKey;

  LabelRenderer(this.repaintBoundaryKey);

  /// Captures the widget behind [repaintBoundaryKey] as a PNG image.
  ///
  /// [pixelRatio] controls the resolution of the output image.
  /// A higher ratio produces a higher-resolution PNG.
  /// Default is 3.0 for crisp print output.
  ///
  /// Returns the [File] path of the saved PNG in the system temp directory,
  /// or `null` if the capture failed.
  Future<String?> renderToPng({double pixelRatio = 3.0}) async {
    try {
      // Find the RenderRepaintBoundary from the key
      final boundary = repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;

      if (boundary == null) {
        debugPrint('LabelRenderer: RenderRepaintBoundary not found.');
        return null;
      }

      // Capture the boundary as an image
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

      // Encode the image to PNG bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) {
        debugPrint('LabelRenderer: Failed to encode image to PNG.');
        return null;
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Save to a temporary file
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/tgc_label_$timestamp.png');
      await file.writeAsBytes(pngBytes);

      debugPrint('LabelRenderer: PNG saved to ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('LabelRenderer: Error rendering PNG: $e');
      return null;
    }
  }
}
