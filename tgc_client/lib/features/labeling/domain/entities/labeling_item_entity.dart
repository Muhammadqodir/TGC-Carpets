import 'package:equatable/equatable.dart';

class LabelingItemEntity extends Equatable {
  final int id;
  final int batchId;
  final String? batchTitle;

  final int plannedQuantity;
  final int producedQuantity;
  final int defectQuantity;

  // ── Variant / product ────────────────────────────────────────────────────
  final int variantId;
  final String? variantSku;
  final String? variantBarcode;
  final String productName;
  final String? colorName;
  final String? colorImageUrl;
  final int? sizeLength;
  final int? sizeWidth;
  final String? qualityName;
  final String? productTypeName;

  const LabelingItemEntity({
    required this.id,
    required this.batchId,
    this.batchTitle,
    required this.plannedQuantity,
    required this.producedQuantity,
    this.defectQuantity = 0,
    required this.variantId,
    this.variantSku,
    this.variantBarcode,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.sizeLength,
    this.sizeWidth,
    this.qualityName,
    this.productTypeName,
  });

  String get sizeLabel {
    if (sizeLength == null || sizeWidth == null) return '—';
    return '$sizeLength×$sizeWidth';
  }

  int get netTarget => (plannedQuantity - defectQuantity).clamp(0, plannedQuantity);

  int get remainingQuantity => (netTarget - producedQuantity).clamp(0, netTarget);

  bool get isFullyLabeled => producedQuantity >= netTarget;

  LabelingItemEntity copyWith({int? producedQuantity, int? defectQuantity}) {
    return LabelingItemEntity(
      id: id,
      batchId: batchId,
      batchTitle: batchTitle,
      plannedQuantity: plannedQuantity,
      producedQuantity: producedQuantity ?? this.producedQuantity,
      defectQuantity: defectQuantity ?? this.defectQuantity,
      variantId: variantId,
      variantSku: variantSku,
      variantBarcode: variantBarcode,
      productName: productName,
      colorName: colorName,
      colorImageUrl: colorImageUrl,
      sizeLength: sizeLength,
      sizeWidth: sizeWidth,
      qualityName: qualityName,
      productTypeName: productTypeName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        batchId,
        plannedQuantity,
        producedQuantity,
        defectQuantity,
        variantId,
      ];
}
