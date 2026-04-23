import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
///     child: RepaintBoundary(key: _captureKey, child: PrintLabel60(...)),
///   ),
/// )
/// ```
/// [RepaintBoundary.toImage(pixelRatio: 1.0)] will capture the label at full
/// print resolution regardless of the FittedBox scale factor.
class PrintLabel60 extends StatelessWidget {
  const PrintLabel60({
    super.key,
    required this.config,
    required this.barcodeValue,
    required this.qrData,
    this.productName,
    this.quality,
    this.type,
    this.color,
    this.sizeLabel,
  });

  final LabelConfig config;

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
    final w = config.widthPx.toDouble();
    final h = config.heightPx.toDouble();
    final pad = w * 0.03;
    final specFontSize = h * 0.09;
    final qrSize = w * 0.22;

    return Container(
      width: w,
      height: h,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: pad),
          Expanded(
            flex: 28,
            child: BarcodeWidget(
              data: qrData,
              barcode: Barcode.code128(),
              drawText: false,
              textPadding: h * 0.018,
              style: TextStyle(
                fontSize: h * 0.055,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: pad),
          Expanded(
            flex: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SpecRow(
                        label: 'Quality',
                        value: quality ?? '—',
                        fontSize: specFontSize,
                      ),
                      _SpecRow(
                        label: 'Design',
                        value: productName ?? '—',
                        fontSize: specFontSize,
                      ),
                      _SpecRow(
                        label: 'Color',
                        value: color ?? '—',
                        fontSize: specFontSize,
                      ),
                      _SpecRow(
                        label: 'Size',
                        value: sizeLabel ?? '—',
                        fontSize: specFontSize,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: pad * 0.4),

          // ── Barcode ───────────────────────────────────────────────────
          Expanded(
            flex: 30,
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
        ],
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
  });

  final String label;
  final String value;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: fontSize * 0.26),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 97,
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
          SizedBox(width: 5), // extra gap for readability
          Expanded(
            child: Text(
              value.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                height: 1,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
