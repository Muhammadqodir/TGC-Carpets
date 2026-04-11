import '../../domain/entities/production_batch_entity.dart';
import '../../domain/entities/production_batch_item_entity.dart';

class ProductionBatchModel extends ProductionBatchEntity {
  const ProductionBatchModel({
    required super.id,
    required super.batchTitle,
    required super.type,
    required super.status,
    super.plannedDatetime,
    super.startedDatetime,
    super.completedDatetime,
    super.notes,
    super.machine,
    super.creator,
    required super.itemsCount,
    required super.totalPlannedQuantity,
    required super.totalSqm,
    super.items = const [],
    required super.createdAt,
    required super.updatedAt,
  });

  factory ProductionBatchModel.fromJson(Map<String, dynamic> json) {
    final machineMap  = json['machine']  as Map<String, dynamic>?;
    final creatorMap  = json['creator']  as Map<String, dynamic>?;
    final itemsList   = json['items']    as List<dynamic>?;

    return ProductionBatchModel(
      id:                  json['id'] as int,
      batchTitle:          json['batch_title'] as String,
      type:                json['type'] as String,
      status:              json['status'] as String,
      plannedDatetime:     json['planned_datetime'] != null
          ? DateTime.parse(json['planned_datetime'] as String)
          : null,
      startedDatetime:     json['started_datetime'] != null
          ? DateTime.parse(json['started_datetime'] as String)
          : null,
      completedDatetime:   json['completed_datetime'] != null
          ? DateTime.parse(json['completed_datetime'] as String)
          : null,
      notes:               json['notes'] as String?,
      machine: machineMap != null
          ? ProductionBatchMachine(
              id:        machineMap['id'] as int,
              name:      machineMap['name'] as String,
              modelName: machineMap['model_name'] as String?,
            )
          : null,
      creator: creatorMap != null
          ? ProductionBatchCreator(
              id:   creatorMap['id'] as int,
              name: creatorMap['name'] as String,
            )
          : null,
      itemsCount: json['items_count'] as int? ?? itemsList?.length ?? 0,
      totalPlannedQuantity: json['total_planned_quantity'] as int? ??
          itemsList?.fold<int>(0, (s, e) =>
              s + ((e as Map<String, dynamic>)['planned_quantity'] as int? ?? 0)) ??
          0,
      totalSqm: (json['total_sqm'] as num?)?.toDouble() ?? 0.0,
      items: itemsList != null
          ? itemsList
              .map((e) => _parseItem(e as Map<String, dynamic>))
              .toList()
          : const [],
      createdAt:  DateTime.parse(json['created_at'] as String),
      updatedAt:  DateTime.parse(json['updated_at'] as String),
    );
  }

  static ProductionBatchItemEntity _parseItem(Map<String, dynamic> json) {
    final variantMap     = json['variant']       as Map<String, dynamic>?;
    final colorMap       = variantMap?['product_color'] as Map<String, dynamic>?;
    final productMap     = colorMap?['product']         as Map<String, dynamic>?;
    final colorInfoMap   = colorMap?['color']            as Map<String, dynamic>?;
    final sizeMap        = variantMap?['product_size']   as Map<String, dynamic>?;
    final productTypeMap = productMap?['product_type']   as Map<String, dynamic>?;
    final sourceItemMap  = json['source_order_item']     as Map<String, dynamic>?;
    final orderMap       = sourceItemMap?['order']       as Map<String, dynamic>?;
    final clientMap      = orderMap?['client']           as Map<String, dynamic>?;

    return ProductionBatchItemEntity(
      id:                       json['id'] as int,
      sourceType:               json['source_type'] as String? ?? 'manual',
      plannedQuantity:          json['planned_quantity'] as int,
      producedQuantity:         json['produced_quantity'] as int?,
      defectQuantity:           json['defect_quantity'] as int?,
      warehouseReceivedQuantity: json['warehouse_received_quantity'] as int?,
      notes:                    json['notes'] as String?,
      sourceOrderItemId:        sourceItemMap?['id'] as int?,
      sourceOrderId:            orderMap?['id'] as int?,
      sourceOrderQuantity:      sourceItemMap?['quantity'] as int?,
      sourceClientShopName:     clientMap?['shop_name'] as String?,
      variantId:                variantMap?['id'] as int? ?? 0,
      variantSku:               variantMap?['sku_code'] as String?,
      variantBarcode:           variantMap?['barcode_value'] as String?,
      productId:                productMap?['id'] as int?,
      productName:              productMap?['name'] as String? ?? '',
      colorName:                colorInfoMap?['name'] as String?,
      colorImageUrl:            colorMap?['image_url'] as String?,
      sizeLength:               sizeMap?['length'] as int?,
      sizeWidth:                sizeMap?['width']  as int?,
      productUnit:              productMap?['unit'] as String?,
      productColorId:           colorMap?['id'] as int?,
      productSizeId:            sizeMap?['id'] as int?,
      productTypeId:            productMap?['product_type_id'] as int?,
      qualityName:              productMap?['quality_name'] as String?,
      productTypeName:          productTypeMap?['type'] as String?,
    );
  }
}
