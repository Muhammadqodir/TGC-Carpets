import '../../domain/entities/scanned_item_entity.dart';

class ScannedItemModel extends ScannedItemEntity {
  const ScannedItemModel({
    required super.item,
    required super.product,
    required super.productionBatch,
    super.destination,
    super.unit,
    super.labelPrints,
    super.reattribution,
    super.stockQuantity,
  });

  factory ScannedItemModel.fromJson(Map<String, dynamic> json) {
    final prints = json['label_prints'] as Map<String, dynamic>?;
    final reattribution = json['reattribution'] as Map<String, dynamic>?;

    return ScannedItemModel(
      item: ScannedItemInfoModel.fromJson(json['item']),
      product: ScannedProductInfoModel.fromJson(json['product']),
      productionBatch:
          ScannedProductionBatchInfoModel.fromJson(json['production_batch']),
      destination: json['destination'] != null
          ? ScannedDestinationInfoModel.fromJson(json['destination'])
          : null,
      unit: json['unit'] != null
          ? ScannedUnitInfoModel.fromJson(json['unit'])
          : null,
      labelPrints: prints == null
          ? null
          : ScannedLabelPrints(
              beforeTracking: prints['before_tracking'] as int? ?? 0,
              prints: [
                for (final p in (prints['prints'] as List? ?? const []))
                  ScannedLabelPrint(
                    printedAt: (p as Map<String, dynamic>)['printed_at'] as String?,
                    printedByName: p['printed_by_name'] as String?,
                    kind: p['kind'] as String? ?? 'print',
                  ),
              ],
            ),
      reattribution: reattribution == null
          ? null
          : ScannedReattributionInfo(
              fromClientName: reattribution['from_client_name'] as String?,
              shipmentId: reattribution['shipment_id'] as int?,
            ),
      stockQuantity: json['stock_quantity'] as int?,
    );
  }
}

class ScannedUnitInfoModel extends ScannedUnitInfo {
  const ScannedUnitInfoModel({
    required super.serial,
    required super.status,
    super.printedAt,
    super.printedByName,
    required super.reprintCount,
  });

  factory ScannedUnitInfoModel.fromJson(Map<String, dynamic> json) {
    return ScannedUnitInfoModel(
      serial: json['serial'],
      status: json['status'],
      printedAt: json['printed_at'],
      printedByName: json['printed_by_name'],
      reprintCount: json['reprint_count'] ?? 0,
    );
  }
}

class ScannedItemInfoModel extends ScannedItemInfo {
  const ScannedItemInfoModel({
    required super.id,
    required super.plannedQuantity,
    required super.producedQuantity,
    required super.defectQuantity,
    required super.warehouseReceivedQuantity,
  });

  factory ScannedItemInfoModel.fromJson(Map<String, dynamic> json) {
    return ScannedItemInfoModel(
      id: json['id'],
      plannedQuantity: json['planned_quantity'] ?? 0,
      producedQuantity: json['produced_quantity'] ?? 0,
      defectQuantity: json['defect_quantity'] ?? 0,
      warehouseReceivedQuantity: json['warehouse_received_quantity'] ?? 0,
    );
  }
}

class ScannedProductInfoModel extends ScannedProductInfo {
  const ScannedProductInfoModel({
    required super.name,
    super.quality,
    super.type,
    super.color,
    super.colorImage,
    super.sizeLength,
    super.sizeWidth,
    super.sizeLabel,
    super.barcode,
    super.sku,
  });

  factory ScannedProductInfoModel.fromJson(Map<String, dynamic> json) {
    return ScannedProductInfoModel(
      name: json['name'],
      quality: json['quality'],
      type: json['type'],
      color: json['color'],
      colorImage: json['color_image'],
      sizeLength: json['size_length'],
      sizeWidth: json['size_width'],
      sizeLabel: json['size_label'],
      barcode: json['barcode'],
      sku: json['sku'],
    );
  }
}

class ScannedProductionBatchInfoModel extends ScannedProductionBatchInfo {
  const ScannedProductionBatchInfoModel({
    required super.id,
    super.batchTitle,
    required super.status,
    required super.type,
    super.plannedDatetime,
    super.completedDatetime,
    super.machineId,
    super.machineName,
    super.employeeName,
    super.responsibleEmployeeName,
    super.createdAt,
  });

  factory ScannedProductionBatchInfoModel.fromJson(Map<String, dynamic> json) {
    return ScannedProductionBatchInfoModel(
      id: json['id'],
      batchTitle: json['batch_title'],
      status: json['status'],
      type: json['type'],
      plannedDatetime: json['planned_datetime'],
      completedDatetime: json['completed_datetime'],
      machineId: json['machine_id'],
      machineName: json['machine_name'],
      employeeName: json['employee_name'],
      responsibleEmployeeName: json['responsible_employee_name'],
      createdAt: json['created_at'],
    );
  }
}

class ScannedDestinationInfoModel extends ScannedDestinationInfo {
  const ScannedDestinationInfoModel({
    required super.type,
    super.clientName,
    super.region,
    super.contactName,
    super.phone,
    super.orderId,
    super.orderUuid,
    super.orderStatus,
    super.orderDate,
    super.orderedQuantity,
    super.shippedQuantity,
  });

  factory ScannedDestinationInfoModel.fromJson(Map<String, dynamic> json) {
    return ScannedDestinationInfoModel(
      type: json['type'],
      clientName: json['client_name'],
      region: json['region'],
      contactName: json['contact_name'],
      phone: json['phone'],
      orderId: json['order_id'],
      orderUuid: json['order_uuid'],
      orderStatus: json['order_status'],
      orderDate: json['order_date'],
      orderedQuantity: json['ordered_quantity'],
      shippedQuantity: json['shipped_quantity'],
    );
  }
}
