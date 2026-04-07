import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:usb_label_print/usb_label_print.dart';

class PrintLabel extends StatelessWidget {
  const PrintLabel({super.key, required this.config});
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
            top: config.heightPx * 0.02,
            left: config.widthPx * 0.40,
            child: Image.asset(
              'assets/label_logo.png',
              height: config.heightPx * 0.15,
            ),
          ),
          Positioned(
            top: config.heightPx * 0.20,
            left: config.widthPx * 0.40,
            right: config.widthPx * 0.10,
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
                  'Rang: Moviy',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.1,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Sifat: Ronaldo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    height: 1.1,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Hajm: 250x350',
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
            right: config.widthPx * 0.40,
            bottom: config.heightPx * 0.40,
            child: QrImageView(
              data: 'https://erp.tgc-carpets.uz/p/12645',
              version: QrVersions.auto,
              padding: EdgeInsets.zero,
              size: config.widthPx * 0.38,
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
                fontSize: fontSize,
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
