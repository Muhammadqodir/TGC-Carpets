import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:usb_label_print/usb_label_print.dart';

class PrintLabel extends StatelessWidget {
  const PrintLabel({super.key, required this.config});
  final LabelConfig config;

  @override
  Widget build(BuildContext context) {
    double fontSize = config.heightPx * 0.12;
    return Container(
      width: config.widthMm,
      height: config.heightMm,
      child: Stack(
        children: [
          Positioned(
            top: config.heightPx * 0.01,
            left: config.widthPx * 0.02,
            right: config.widthPx * 0.02,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SpecText(
                  fontSize: fontSize,
                  label: "Model",
                  value: "8546",
                ),
                SizedBox(height: config.heightPx * 0.015),
                _SpecText(
                  fontSize: fontSize,
                  label: "Size",
                  value: "250x350",
                ),
                SizedBox(height: config.heightPx * 0.015),
                _SpecText(
                  fontSize: fontSize,
                  label: "Quality",
                  value: "Ronaldo",
                ),
                SizedBox(height: config.heightPx * 0.015),
                _SpecText(
                  fontSize: fontSize,
                  label: "Color",
                  value: "Blue",
                ),
              ],
            ),
          ),
          Positioned(
            top: config.heightPx * 0.01,
            right: config.widthPx * 0.02,
            child: QrImageView(
              data: 'wharehouse_document_id_here/product_variant_id_here',
              version: QrVersions.auto,
              padding: EdgeInsets.zero,
              size: config.widthPx * 0.18,
            ),
          ),
          Positioned(
            bottom: config.heightPx * 0.02,
            left: config.widthPx * 0.02,
            right: config.widthPx * 0.02,
            child: BarcodeWidget(
              height: config.heightPx * 0.35,
              drawText: true,
              textPadding: config.heightPx * 0.02,
              style: TextStyle(
                fontSize: config.heightPx * 0.05,
                fontWeight: FontWeight.bold,
              ),
              data: 'barcode here',
              barcode: Barcode.code128(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecText extends StatelessWidget {
  const _SpecText({
    super.key,
    required this.fontSize,
    required this.label,
    required this.value,
  });
  final double fontSize;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 91,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              height: 1.1,
              fontSize: fontSize * 0.7,
            ),
          ),
        ),
        Text(
          ":",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            height: 1.1,
            fontSize: fontSize * 0.7,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              height: 1,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
