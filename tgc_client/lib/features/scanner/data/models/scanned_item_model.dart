import '../../domain/entities/scanned_item_entity.dart';

class ScannedItemModel extends ScannedItemEntity {
  const ScannedItemModel({
    required super.item,
    required super.product,
    required super.productionBatch,
    super.destination,
  });

  factory ScannedItemModel.fromJson(Map<String, dynamic> json) {
    return ScannedItemModel(
      item: ScannedItemInfoModel.fromJson(json['item']),
      product: ScannedProductInfoModel.fromJson(json['product']),
      productionBatch:
          ScannedProductionBatchInfoModel.fromJson(json['production_batch']),
      destination: json['destination'] != null
          ? ScannedDestinationInfoModel.fromJson(json['destination'])
          : null,
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
    );
  }
}

class ScannedDestinationInfoModel extends ScannedDestinationInfo {
  const ScannedDestinationInfoModel({
    required super.type,
    super.clientName,
    super.region,
    super.orderUuid,
  });

  factory ScannedDestinationInfoModel.fromJson(Map<String, dynamic> json) {
    return ScannedDestinationInfoModel(
      type: json['type'],
      clientName: json['client_name'],
      region: json['region'],
      orderUuid: json['order_uuid'],
    );
  }
}
