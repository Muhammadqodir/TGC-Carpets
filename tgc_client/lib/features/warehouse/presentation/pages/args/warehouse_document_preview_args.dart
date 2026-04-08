/// Payload passed from [AddWarehouseDocumentPage] to [WarehouseDocumentPreviewPage].
class WarehouseDocumentPreviewArgs {
  final String type;
  final DateTime documentDate;
  final String? notes;
  final String username;
  final List<WarehouseItemPreviewRow> items;

  const WarehouseDocumentPreviewArgs({
    required this.type,
    required this.documentDate,
    this.notes,
    required this.username,
    required this.items,
  });
}

class WarehouseItemPreviewRow {
  final int productId;
  final String productName;
  final String? quality;
  final String? type;
  final String? color;
  final int? productColorId;
  final int? productSizeId;
  final String? sizeLabel;
  final int? sizeLength;
  final int? sizeWidth;
  final int quantity;
  final String? itemNotes;

  const WarehouseItemPreviewRow({
    required this.productId,
    required this.productName,
    this.quality,
    this.type,
    this.color,
    this.productColorId,
    this.productSizeId,
    this.sizeLabel,
    this.sizeLength,
    this.sizeWidth,
    required this.quantity,
    this.itemNotes,
  });

  /// Area in m² for this row. Assumes [sizeLength] and [sizeWidth] are in
  /// centimetres (e.g. 200 × 300 cm → 6 м²).
  double? get squareMeters =>
      (sizeLength != null && sizeWidth != null)
          ? sizeLength! * sizeWidth! * quantity / 10000.0
          : null;
}

/// Formats a square-metre value, suppressing the decimal when it is zero.
String fmtSqM(double v) {
  if (v == v.truncateToDouble()) return '${v.toInt()} м²';
  return '${v.toStringAsFixed(2)} м²';
}
