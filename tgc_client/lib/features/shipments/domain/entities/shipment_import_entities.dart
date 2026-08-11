import 'package:equatable/equatable.dart';

class ShipmentImportClientEntity extends Equatable {
  final int id;
  final String shopName;
  final String region;
  final String? contactName;
  final int itemCount;

  const ShipmentImportClientEntity({
    required this.id,
    required this.shopName,
    required this.region,
    this.contactName,
    required this.itemCount,
  });

  String get displayName =>
      contactName != null ? '$shopName ($contactName)' : shopName;

  @override
  List<Object?> get props => [id, shopName, region, contactName, itemCount];
}

class ShipmentImportQualityEntity extends Equatable {
  final String qualityName;
  final int itemCount;

  const ShipmentImportQualityEntity({
    required this.qualityName,
    required this.itemCount,
  });

  @override
  List<Object?> get props => [qualityName, itemCount];
}

/// A single shippable order item ready for import into the shipment form.
class ShipmentImportItemEntity extends Equatable {
  /// Null only for a scanned carpet the selected client has no open order
  /// line for — the "add anyway" case, where the backend creates the order
  /// line at submit time. Items from the order/stock wizards always have one.
  final int? orderItemId;
  final int variantId;
  final String productName;
  final String? colorName;
  final String? colorImageUrl;
  final String? qualityName;
  final String? typeName;
  final int? sizeLength;
  final int? sizeWidth;
  final String? productUnit;
  final String? edgeCode;
  final String? edgeTitle;

  /// How many are still unshipped on the order line. 0 when there is no order
  /// line yet ([isOnClientOrder] false), where nothing caps the quantity.
  final int availableQuantity;

  /// Warehouse stock for this variant. Informational only — a carpet whose
  /// label was just scanned is physically present whatever this says, and the
  /// backend books in the difference when the shipment is saved.
  final int stockQuantity;

  /// Shop name of the client this carpet was produced for, when that is
  /// someone other than the one selected on the form. Null when the label
  /// carries no order link, or when it is this client's own carpet.
  ///
  /// Non-null means shipping this carpet takes it off that client's order:
  /// their "Tayyor" count drops and the factory owes them a replacement. The
  /// scanner asks before doing that, whether or not this client has an order
  /// line of their own for it.
  final String? producedForClient;

  /// The production batch item the scanned label resolved to, sent back with
  /// the shipment so the backend can move the production record onto the line
  /// these carpets ship against. Null for items picked from the order/stock
  /// wizards and for variant-only label shapes, which name no single carpet.
  final int? productionBatchItemId;

  const ShipmentImportItemEntity({
    required this.orderItemId,
    required this.variantId,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.qualityName,
    this.typeName,
    this.sizeLength,
    this.sizeWidth,
    this.productUnit,
    this.edgeCode,
    this.edgeTitle,
    required this.availableQuantity,
    this.stockQuantity = 0,
    this.producedForClient,
    this.productionBatchItemId,
  });

  String? get sizeLabel =>
      sizeLength != null && sizeWidth != null ? '$sizeWidth×$sizeLength' : null;

  /// False = the scan resolved a real carpet, but this client has no open
  /// order line for it. Adding it anyway makes the backend create one.
  bool get isOnClientOrder => orderItemId != null;

  @override
  List<Object?> get props => [
        orderItemId, variantId, productName, colorName, colorImageUrl,
        qualityName, typeName, sizeLength, sizeWidth, productUnit,
        edgeCode, edgeTitle, availableQuantity, stockQuantity,
        producedForClient, productionBatchItemId,
      ];
}
