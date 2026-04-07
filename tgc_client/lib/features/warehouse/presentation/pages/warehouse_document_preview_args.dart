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
  final String productDetails;
  final int? productSizeId;
  final String? sizeLabel;
  final int quantity;
  final String? itemNotes;

  const WarehouseItemPreviewRow({
    required this.productId,
    required this.productName,
    required this.productDetails,
    this.productSizeId,
    this.sizeLabel,
    required this.quantity,
    this.itemNotes,
  });
}
