import 'package:equatable/equatable.dart';

import '../../../production/domain/entities/production_batch_item_entity.dart';

class ImportClientEntity extends Equatable {
  final int id;
  final String shopName;
  final String region;
  final String? contactName;
  final int itemCount;

  const ImportClientEntity({
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

class ImportQualityEntity extends Equatable {
  final String qualityName;
  final int itemCount;

  const ImportQualityEntity({
    required this.qualityName,
    required this.itemCount,
  });

  @override
  List<Object?> get props => [qualityName, itemCount];
}

/// A flat production batch item ready for warehouse import.
/// Extends [ProductionBatchItemEntity] and adds batch context.
class ImportItemEntity extends ProductionBatchItemEntity {
  final int batchId;
  final String batchTitle;

  const ImportItemEntity({
    required super.id,
    required super.sourceType,
    required super.plannedQuantity,
    super.producedQuantity,
    super.defectQuantity,
    super.warehouseReceivedQuantity,
    super.notes,
    super.sourceOrderItemId,
    super.sourceOrderId,
    super.sourceOrderQuantity,
    super.sourceClientShopName,
    super.sourceClientRegion,
    required super.variantId,
    super.variantSku,
    super.variantBarcode,
    super.productId,
    required super.productName,
    super.colorName,
    super.colorImageUrl,
    super.sizeLength,
    super.sizeWidth,
    super.productUnit,
    super.productColorId,
    super.productSizeId,
    super.productTypeId,
    super.qualityName,
    super.productTypeName,
    super.edgeCode,
    required this.batchId,
    required this.batchTitle,
  });

  int get available =>
      ((producedQuantity ?? 0) - (warehouseReceivedQuantity ?? 0))
          .clamp(0, producedQuantity ?? 0);

  @override
  List<Object?> get props => [...super.props, batchId, batchTitle];
}
