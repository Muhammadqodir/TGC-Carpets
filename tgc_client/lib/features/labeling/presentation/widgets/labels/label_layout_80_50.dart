import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';

/// The label's layout, shared by both templates, on a fixed 945 × 591 canvas
/// (80 × 50 mm at 300 DPI):
///
/// ```
/// Quality : RONALDO                 ═
/// Design  : 1568                    ═  carpet number
/// Size    : 400×10125 R             ═  turned −90°, digits
/// Color   : BEIGE                   ═  on the right
///
/// ║║║║║║║║║║║║║║║║               ┌──┐
/// 2984200059847      S_123_04_14 15.59
/// ```
///
/// The square code is exactly as tall as the product barcode's bars, and the
/// print code under it sits on the line of the barcode's digits.
///
/// Barcodes are sized from their own bars, never stretched to fill a space, so
/// the bars stay even when the label is rasterised.
class Label8050Layout extends StatelessWidget {
  const Label8050Layout({
    super.key,
    required this.barcodeValue,
    required this.scanData,
    required this.specLabels,
    required this.specLabelStyle,
    this.carpetBarcode,
    this.productName,
    this.quality,
    this.color,
    this.sizeLabel,
    this.edgeCode,
    this.printCode,
  });

  static const double canvasWidth = 945;
  static const double canvasHeight = 591;

  /// Width of the narrowest bar, about 0.29 mm when printed. The widest that
  /// keeps both barcodes on one row with the white margins they need.
  static const double barModule = 3.5;

  /// Barcode height, including its digits.
  static const double _barcodeHeight = 140;

  /// The digits under a barcode and the gap above them.
  static const double _digitsSize = 30;
  static const double _digitsGap = 8;

  /// Height of a barcode's bars alone, and so of the square code.
  static const double _barsHeight = _barcodeHeight - _digitsSize - _digitsGap;

  /// The white margin Code 128 needs on each side, 10 bar widths.
  static const double _quietZone = 10 * barModule;

  static const double _margin = 20;

  static const double _specFontSize = 74;

  final String barcodeValue;

  /// What the square code holds: the same text the old QR code held.
  final String scanData;

  /// The unique number of this one carpet. The space stays empty without it,
  /// so the rest of the label never moves.
  final String? carpetBarcode;

  /// Row captions, in order: quality, design, size, colour.
  final List<String> specLabels;
  final Label8050CaptionStyle specLabelStyle;

  final String? productName;
  final String? quality;
  final String? color;
  final String? sizeLabel;
  final String? edgeCode;
  final String? printCode;

  @override
  Widget build(BuildContext context) {
    final size =
        edgeCode != null ? '${sizeLabel ?? '—'} $edgeCode' : sizeLabel ?? '—';

    return FittedBox(
      fit: BoxFit.contain,
      child: Container(
        width: canvasWidth,
        height: canvasHeight,
        color: Colors.white,
        padding: const EdgeInsets.all(_margin),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                // The details stop short of the carpet number on the right.
                Padding(
                  padding: const EdgeInsets.only(
                    right: _barcodeHeight + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SpecRow(
                        caption: specLabels[0],
                        captionStyle: specLabelStyle,
                        value: quality ?? '—',
                      ),
                      _SpecRow(
                        caption: specLabels[1],
                        captionStyle: specLabelStyle,
                        value: productName ?? '—',
                        isBold: true,
                      ),
                      _SpecRow(
                        caption: specLabels[2],
                        captionStyle: specLabelStyle,
                        value: size,
                        isBold: true,
                      ),
                      _SpecRow(
                        caption: specLabels[3],
                        captionStyle: specLabelStyle,
                        value: color ?? '—',
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: _barcodeHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: _quietZone - _margin),
                      _LinearBarcode(barcodeValue),
                      const SizedBox(width: _quietZone),
                      // A long print code shrinks before it can reach the
                      // product barcode.
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _ScanCode(scanData),
                            if (printCode != null) ...[
                              const SizedBox(height: _digitsGap),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: _PrintCode(printCode!),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (carpetBarcode != null)
              Positioned(
                top: _quietZone - _margin,
                right: 0,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: _LinearBarcode(carpetBarcode!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// How a template draws the captions in front of its values.
class Label8050CaptionStyle {
  const Label8050CaptionStyle({
    required this.width,
    required this.fontSize,
    required this.lineHeight,
    this.maxLines = 1,
  });

  final double width;
  final double fontSize;
  final double lineHeight;
  final int maxLines;
}

/// A plain Code 128: the bars with the digits centred below, as narrow as the
/// bars can be printed.
class _LinearBarcode extends StatelessWidget {
  const _LinearBarcode(this.data);

  final String data;

  @override
  Widget build(BuildContext context) {
    final barcode = Barcode.code128();

    return SizedBox(
      width: _modulesOf(barcode, data, 100) * Label8050Layout.barModule,
      height: Label8050Layout._barcodeHeight,
      child: BarcodeWidget(
        data: data,
        barcode: barcode,
        drawText: true,
        textPadding: Label8050Layout._digitsGap,
        style: const TextStyle(
          fontSize: Label8050Layout._digitsSize,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
  }
}

/// The small square code everyone in the factory scans, exactly as tall as
/// the product barcode's bars.
class _ScanCode extends StatelessWidget {
  const _ScanCode(this.data);

  final String data;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: Label8050Layout._barsHeight,
      child: BarcodeWidget(
        data: data,
        barcode: Barcode.dataMatrix(),
        drawText: false,
      ),
    );
  }
}

/// How many of its narrowest bars a Code 128 spans: every one has a bar that
/// narrow in its stop pattern.
int _modulesOf(Barcode barcode, String data, double height) {
  const span = 1000.0;
  final narrowest = barcode
      .make(data, width: span, height: height)
      .whereType<BarcodeBar>()
      .map((bar) => bar.width)
      .reduce((a, b) => a < b ? a : b);
  return (span / narrowest).round();
}

/// "S_123_04_14 15.59" under the square code, on the line of the digits.
class _PrintCode extends StatelessWidget {
  const _PrintCode(this.code);

  final String code;

  @override
  Widget build(BuildContext context) {
    return Text(
      code,
      maxLines: 1,
      softWrap: false,
      style: const TextStyle(
        fontSize: Label8050Layout._digitsSize,
        height: 1,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.caption,
    required this.captionStyle,
    required this.value,
    this.isBold = false,
  });

  final String caption;
  final Label8050CaptionStyle captionStyle;
  final String value;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    const fontSize = Label8050Layout._specFontSize;

    return Padding(
      padding: const EdgeInsets.only(bottom: fontSize * 0.26),
      child: SizedBox(
        height: fontSize,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: captionStyle.width,
              child: Text(
                caption,
                maxLines: captionStyle.maxLines,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: captionStyle.fontSize,
                  height: captionStyle.lineHeight,
                ),
              ),
            ),
            const Text(
              ':',
              style: TextStyle(fontSize: fontSize * 0.78, height: 1.1),
            ),
            const SizedBox(width: fontSize * 0.1),
            // A long value gets smaller instead of losing its end: on a carpet
            // label the end of a name is what tells two products apart.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text(
                  value.toUpperCase(),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
