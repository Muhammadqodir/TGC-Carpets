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

  /// What the order line still owes, regardless of stock. Null from servers
  /// before October 2026, where [availableQuantity] (capped by stock in the
  /// wizard) is the best guess. Past this the row is beyond the order.
  final int? orderRemaining;

  /// The order this line belongs to, and its date. Shown on the form so two
  /// rows of the same carpet read as two orders, not as a duplicate.
  final int? orderId;
  final String? orderDate;

  /// What this client still owes for this carpet across ALL their open
  /// orders, as of the scan. Only past this is a carpet beyond the order;
  /// past one line it just goes on the client's next order.
  final int? clientOpenRemaining;

  /// Every open order line the client has for this carpet, the scan's choice
  /// first: order item id, order id, order date (`YYYY-MM-DD`), remaining.
  /// Empty from the stock wizard and from servers before October 2026.
  final List<({int orderItemId, int? orderId, String? orderDate, int remaining})> openLines;

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

  /// Why an off-order scan ([isOnClientOrder] false) has no line: null or
  /// `no_open_line` when the client never ordered this carpet (or every such
  /// line has shipped), `open_lines_full` when they did and every open line
  /// is already on this form. Changes only what the confirmation sheet says;
  /// saving works the same either way.
  final String? unmatchedReason;

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
    this.orderRemaining,
    this.orderId,
    this.orderDate,
    this.clientOpenRemaining,
    this.openLines = const [],
    this.stockQuantity = 0,
    this.producedForClient,
    this.productionBatchItemId,
    this.unmatchedReason,
  });

  String? get sizeLabel =>
      sizeLength != null && sizeWidth != null ? '$sizeWidth×$sizeLength' : null;

  /// False = the scan resolved a real carpet, but this client has no open
  /// order line for it. Adding it anyway makes the backend create one.
  bool get isOnClientOrder => orderItemId != null;

  /// True when the client did order this carpet, but every open line for it
  /// is already filled on the form — shipping it goes beyond the order.
  bool get isBeyondOrder => unmatchedReason == 'open_lines_full';

  @override
  List<Object?> get props => [
        orderItemId, variantId, productName, colorName, colorImageUrl,
        qualityName, typeName, sizeLength, sizeWidth, productUnit,
        edgeCode, edgeTitle, availableQuantity, orderRemaining, orderId, orderDate,
        clientOpenRemaining, openLines, stockQuantity,
        producedForClient, productionBatchItemId, unmatchedReason,
      ];
}
