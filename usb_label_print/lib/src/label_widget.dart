import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'label_config.dart';

/// A fixed-size label widget designed for thermal labels.
///
/// Uses [LabelConfig] to calculate exact pixel dimensions from
/// physical size (mm) and printer DPI. Default is 58mm x 40mm @ 203 DPI.
///
/// The widget renders text, a QR code, and an optional logo image
/// within those dimensions.
class LabelWidget extends StatelessWidget {
  /// The main text displayed on the label (e.g., product name or SKU).
  final String text;

  /// The data encoded in the QR code.
  final String qrData;

  /// Optional logo/image widget to display on the label.
  final Widget? logo;

  /// Label configuration (size in mm + DPI). Determines pixel dimensions.
  final LabelConfig config;

  /// Background color of the label.
  final Color backgroundColor;

  /// Text style for the main label text.
  final TextStyle? textStyle;

  const LabelWidget({
    super.key,
    required this.text,
    required this.qrData,
    this.logo,
    this.config = LabelConfig.preset58x40,
    this.backgroundColor = Colors.white,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final style = textStyle ??
        const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        );

    final labelWidth = config.widthPx.toDouble();
    final labelHeight = config.heightPx.toDouble();
    // QR code sized relative to the shorter dimension (height)
    final qrSize = labelHeight * 0.75;

    return Container(
      width: labelWidth,
      height: labelHeight,
      color: backgroundColor,
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: QR code
          SizedBox(
            width: qrSize,
            height: qrSize,
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Right side: text + optional logo
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Optional logo
                if (logo != null) ...[
                  SizedBox(
                    height: 48,
                    child: logo!,
                  ),
                  const SizedBox(height: 8),
                ],

                // Main text (multiline)
                Flexible(
                  child: Text(
                    text,
                    style: style,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
