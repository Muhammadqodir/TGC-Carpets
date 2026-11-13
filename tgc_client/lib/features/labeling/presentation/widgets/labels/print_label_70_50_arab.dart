import 'package:flutter/material.dart';

import 'label_layout_80_50.dart';

/// The label with English and Arabic captions, on a fixed canvas, 80 × 50 mm
/// at 300 DPI. The layout itself is in [Label8050Layout].
///
/// For screen preview, wrap this with [FittedBox] inside a sized container:
/// ```dart
/// SizedBox(
///   width: displayWidth,
///   height: displayWidth / (config.widthPx / config.heightPx),
///   child: FittedBox(
///     fit: BoxFit.contain,
///     child: RepaintBoundary(key: _captureKey, child: PrintLabel7050Arab(...)),
///   ),
/// )
/// ```
/// [RepaintBoundary.toImage(pixelRatio: 1.0)] will capture the label at full
/// print resolution regardless of the FittedBox scale factor.
class PrintLabel7050Arab extends StatelessWidget {
  const PrintLabel7050Arab({
    super.key,
    required this.barcodeValue,
    required this.qrData,
    this.carpetBarcode,
    this.productName,
    this.quality,
    this.type,
    this.color,
    this.sizeLabel,
    this.edgeCode,
    this.printCode,
  });

  /// Human-readable product name / model shown in the spec section.
  final String? productName;

  /// Quality tier label (e.g. "Ronaldo").
  final String? quality;

  /// Product type label.
  final String? type;

  /// Colour name.
  final String? color;

  /// Formatted size string (e.g. "200x300").
  final String? sizeLabel;

  /// Edge code (e.g. "R").
  final String? edgeCode;

  /// Product barcode (e.g. "2984200000429"), printed as a plain Code 128.
  final String barcodeValue;

  /// The unique number of this one carpet, printed as a second Code 128.
  final String? carpetBarcode;

  /// Small code printed vertically on the right edge, e.g. "S_123_04_14 15.59"
  /// (see label_print_code.dart). Left off when null.
  final String? printCode;

  /// The text scanned from the label, printed as a Data Matrix.
  /// See label_qr_format.dart.
  final String qrData;

  @override
  Widget build(BuildContext context) {
    return Label8050Layout(
      barcodeValue: barcodeValue,
      scanData: qrData,
      carpetBarcode: carpetBarcode,
      specLabels: const [
        'Quality\nالجودة',
        'Design\nالتصميم',
        'Size\nالحجم',
        'Color\nاللون',
      ],
      specLabelStyle: const Label8050CaptionStyle(
        width: 148,
        fontSize: 37,
        lineHeight: 1,
        maxLines: 2,
      ),
      productName: productName,
      quality: quality,
      color: color,
      sizeLabel: sizeLabel,
      edgeCode: edgeCode,
      printCode: printCode,
    );
  }
}
