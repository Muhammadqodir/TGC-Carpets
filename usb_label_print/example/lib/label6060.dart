import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:usb_label_print/usb_label_print.dart';

class PrintLabel60 extends StatelessWidget {
  const PrintLabel60 ({super.key, required this.config});
  final LabelConfig config;

  @override
  Widget build(BuildContext context) {
    double fontSize = config.heightPx * 0.08;
    return Container(
      width: config.widthMm,
      height: config.heightMm,
      child: Stack(
        children: [
          Positioned(
            top: config.heightPx * 0.35,
            left: config.widthPx * 0.02,
            right: config.widthPx * 0.02,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Model: 8546',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.1,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Color: Moviy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.1,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Quality: Ronaldo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.1,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Size: 250x350',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.1,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: config.heightPx * 0.02,
            left: config.widthPx * 0.02,
            child: QrImageView(
              data: 'https://erp.tgc-carpets.uz/p/12645',
              version: QrVersions.auto,
              padding: EdgeInsets.zero,
              size: config.widthPx * 0.30,
            ),
          ),
          Positioned(
            bottom: config.heightPx * 0.02,
            left: config.widthPx * 0.02,
            right: config.widthPx * 0.02,
            child: BarcodeWidget(
              height: config.heightPx * 0.20,
              drawText: true,
              textPadding: config.heightPx * 0.02,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              data: '4565-Q1-350x450',
              barcode: Barcode.code128(),
            ),
          ),
        ],
      ),
    );
  }
}
