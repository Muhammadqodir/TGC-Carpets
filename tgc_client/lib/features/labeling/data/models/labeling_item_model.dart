import '../../domain/entities/labeling_item_entity.dart';

class LabelingItemModel extends LabelingItemEntity {
  const LabelingItemModel({
    required super.id,
    required super.batchId,
    super.batchTitle,
    super.machineId,
    super.machineName,
    super.clientName,
    required super.plannedQuantity,
    required super.producedQuantity,
    super.defectQuantity = 0,
    required super.variantId,
    super.variantSku,
    super.variantBarcode,
    required super.productName,
    super.colorName,
    super.colorImageUrl,
    super.sizeLength,
    super.sizeWidth,
    super.qualityName,
    super.productTypeName,
    super.isTypePrintable = true,
    super.edgeCode,
    super.unitSerial,
  });

  /// `unitSerial` comes from a SIBLING top-level `unit` key in the
  /// print-label response, not from inside `json` (which is `body['data']`)
  /// — see LabelingRemoteDataSourceImpl.printLabel(). Absent (and this
  /// param omitted) for the plain labeling-items list response, which has
  /// no `unit` key at all.
  factory LabelingItemModel.fromJson(Map<String, dynamic> json, {String? unitSerial}) {
    final variantMap     = json['variant']              as Map<String, dynamic>?;
    final colorMap       = variantMap?['product_color'] as Map<String, dynamic>?;
    final productMap     = colorMap?['product']         as Map<String, dynamic>?;
    final colorInfoMap   = colorMap?['color']           as Map<String, dynamic>?;
    final sizeMap        = variantMap?['product_size']  as Map<String, dynamic>?;
    final edgeMap        = variantMap?['product_edge']  as Map<String, dynamic>?;
    final productTypeMap = productMap?['product_type']  as Map<String, dynamic>?;

    return LabelingItemModel(
      id:              json['id'] as int,
      batchId:         json['production_batch_id'] as int,
      batchTitle:      json['batch_title'] as String?,
      machineId:       json['machine_id'] as int?,
      machineName:     json['machine_name'] as String?,
      clientName:      json['client_name'] as String?,
      plannedQuantity:  json['planned_quantity'] as int,
      producedQuantity: (json['produced_quantity'] as int?) ?? 0,
      defectQuantity:   (json['defect_quantity']   as int?) ?? 0,
      variantId:       variantMap?['id'] as int? ?? 0,
      variantSku:      variantMap?['sku_code'] as String?,
      variantBarcode:  variantMap?['barcode_value'] as String?,
      productName:     productMap?['name'] as String? ?? '',
      colorName:       colorInfoMap?['name'] as String?,
      colorImageUrl:   colorMap?['image_url'] as String?,
      sizeLength:      sizeMap?['length'] as int?,
      sizeWidth:       sizeMap?['width']  as int?,
      qualityName:     productMap?['quality_name'] as String?,
      productTypeName: productTypeMap?['type'] as String?,
      isTypePrintable: productTypeMap?['is_printable'] as bool? ?? true,
      edgeCode:        edgeMap?['code'] as String?,
      unitSerial:      unitSerial,
    );
  }
}
