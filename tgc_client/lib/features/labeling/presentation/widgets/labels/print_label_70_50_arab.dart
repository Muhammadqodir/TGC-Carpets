import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:usb_label_print/usb_label_print.dart';

/// A fully parameterised label widget that renders at [config.widthPx] ×
/// [config.heightPx] logical pixels — the exact dimensions required by the
/// thermal printer.
///
/// For screen preview, wrap this with [FittedBox] inside a sized container:
/// ```dart
/// SizedBox(
///   width: displayWidth,
///   height: displayWidth / (config.widthPx / config.heightPx),
///   child: FittedBox(
///     fit: BoxFit.contain,
///     child: RepaintBoundary(key: _captureKey, child: PrintLabel7050(...)),
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
    this.productName,
    this.quality,
    this.type,
    this.color,
    this.sizeLabel,
  });

  /// Fixed internal canvas: 80 × 50 mm at 300 DPI.
  static const _kConfig = LabelConfig(widthMm: 80, heightMm: 50, dpi: 300);

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

  /// Value encoded into the Code-128 barcode (e.g. "TGC-VAR-00000042").
  final String barcodeValue;

  /// Data encoded into the QR code — format recommended: "<docId>/<variantId>".
  final String qrData;

  @override
  Widget build(BuildContext context) {
    final w = _kConfig.widthPx.toDouble();
    final h = _kConfig.heightPx.toDouble();
    final pad = w * 0.015;
    final specFontSize = h * 0.125;

    return FittedBox(
      fit: BoxFit.contain,
      child: Container(
      width: w,
      height: h,
      color: Colors.white,
      padding: EdgeInsets.all(pad * 1.5),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: pad),
                    _SpecRow(
                      label: 'Quality',
                      value: quality ?? '—',
                      fontSize: specFontSize,
                    ),
                    _SpecRow(
                      label: 'Design',
                      value: productName ?? '—',
                      fontSize: specFontSize,
                      isBold: true,
                    ),
                    _SpecRow(
                      label: 'Size',
                      value: sizeLabel ?? '—',
                      fontSize: specFontSize,
                      isBold: true,
                    ),
                    _SpecRow(
                      label: 'Color',
                      value: color ?? '—',
                      fontSize: specFontSize,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: h * 0.27,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: h * 0.25,
                        child: BarcodeWidget(
                          data: barcodeValue,
                          barcode: Barcode.code128(),
                          drawText: true,
                          textPadding: h * 0.018,
                          style: TextStyle(
                            fontSize: h * 0.055,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: pad),
                    SizedBox(
                      height: h * 0.276,
                      width: h * 0.276,
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: BarcodeWidget(
                          data: qrData,
                          barcode: Barcode.qrCode(),
                          drawText: false,
                          textPadding: h * 0.018,
                          style: TextStyle(
                            fontSize: h * 0.055,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Barcode ───────────────────────────────────────────────────
            ],
          ),
          Positioned(
            bottom: h * 0.32,
            right: 10,
            child: Text(
              "صحيح",
              style: TextStyle(
                fontSize: specFontSize*1.2,
                height: 1,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Internal spec row ─────────────────────────────────────────────────────────

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.label,
    required this.value,
    required this.fontSize,
    this.isBold = false,
  });

  final String label;
  final String value;
  final double fontSize;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: fontSize * 0.26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: fontSize * 2.4,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: fontSize * 0.65,
                height: 1.1,
              ),
            ),
          ),
          Text(
            ':',
            style: TextStyle(
              fontSize: fontSize * 0.78,
              height: 1.1,
            ), // gap between label and value
          ),
          SizedBox(width: fontSize * 0.1), // extra gap for readability
          Expanded(
            child: Text(
              value.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                height: 1,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
