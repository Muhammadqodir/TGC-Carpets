/// Args passed to [PrintLabelsPage] after a warehouse document is created.
class PrintLabelItem {
  final String productName;
  final String? quality;
  final String? type;
  final String? color;
  final String? sizeLabel;

  /// Product barcode (e.g. "2984200000429"), see product_barcode.dart.
  final String barcodeValue;

  /// Data encoded into the QR code — format: "<docId>/<variantId>".
  final String qrData;

  /// How many copies to print during bulk printing.
  final int quantity;

  const PrintLabelItem({
    required this.productName,
    this.quality,
    this.type,
    this.color,
    this.sizeLabel,
    required this.barcodeValue,
    required this.qrData,
    required this.quantity,
  });
}

class PrintLabelsArgs {
  final int documentId;
  final List<PrintLabelItem> items;

  const PrintLabelsArgs({
    required this.documentId,
    required this.items,
  });
}
