import 'package:equatable/equatable.dart';

class ScannedItemEntity extends Equatable {
  final ScannedItemInfo item;
  final ScannedProductInfo product;
  final ScannedProductionBatchInfo productionBatch;
  final ScannedDestinationInfo? destination;

  const ScannedItemEntity({
    required this.item,
    required this.product,
    required this.productionBatch,
    this.destination,
  });

  @override
  List<Object?> get props => [item, product, productionBatch, destination];
}

class ScannedItemInfo extends Equatable {
  final int id;
  final int plannedQuantity;
  final int producedQuantity;
  final int defectQuantity;
  final int warehouseReceivedQuantity;

  const ScannedItemInfo({
    required this.id,
    required this.plannedQuantity,
    required this.producedQuantity,
    required this.defectQuantity,
    required this.warehouseReceivedQuantity,
  });

  @override
  List<Object?> get props => [
        id,
        plannedQuantity,
        producedQuantity,
        defectQuantity,
        warehouseReceivedQuantity,
      ];
}

class ScannedProductInfo extends Equatable {
  final String name;
  final String? quality;
  final String? type;
  final String? color;
  final String? colorImage;
  final int? sizeLength;
  final int? sizeWidth;
  final String? sizeLabel;
  final String? barcode;
  final String? sku;

  const ScannedProductInfo({
    required this.name,
    this.quality,
    this.type,
    this.color,
    this.colorImage,
    this.sizeLength,
    this.sizeWidth,
    this.sizeLabel,
    this.barcode,
    this.sku,
  });

  @override
  List<Object?> get props => [
        name,
        quality,
        type,
        color,
        colorImage,
        sizeLength,
        sizeWidth,
        sizeLabel,
        barcode,
        sku,
      ];
}

class ScannedProductionBatchInfo extends Equatable {
  final int id;
  final String? batchTitle;
  final String status;
  final String type;
  final String? plannedDatetime;
  final String? completedDatetime;
  final int? machineId;
  final String? machineName;
  final String? employeeName;
  final String? responsibleEmployeeName;

  const ScannedProductionBatchInfo({
    required this.id,
    this.batchTitle,
    required this.status,
    required this.type,
    this.plannedDatetime,
    this.completedDatetime,
    this.machineId,
    this.machineName,
    this.employeeName,
    this.responsibleEmployeeName,
  });

  @override
  List<Object?> get props => [
        id,
        batchTitle,
        status,
        type,
        plannedDatetime,
        completedDatetime,
        machineId,
        machineName,
        employeeName,
        responsibleEmployeeName,
      ];
}

class ScannedDestinationInfo extends Equatable {
  final String type; // 'client' or 'warehouse'
  final String? clientName;
  final String? region;
  final String? orderUuid;

  const ScannedDestinationInfo({
    required this.type,
    this.clientName,
    this.region,
    this.orderUuid,
  });

  bool get isForClient => type == 'client';
  bool get isForWarehouse => type == 'warehouse';

  @override
  List<Object?> get props => [type, clientName, region, orderUuid];
}
