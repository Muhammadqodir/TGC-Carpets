import 'package:equatable/equatable.dart';

class LabelingItemEntity extends Equatable {
  final int id;
  final int batchId;
  final String? batchTitle;
  final int? machineId;
  final String? machineName;
  final String? clientName;

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
  final bool isTypePrintable;
  final String? edgeCode;

  /// The per-carpet unit serial minted by the last print-label call
  /// (`TGC-U-00001234`) — see instructions/phase-3/02-production-units-serials.md.
  /// Null on an item that has never been printed via this session (e.g.
  /// freshly loaded from the labeling-items list, before any print), and
  /// on an idempotency-key replay (see ProductionBatchService's docblock
  /// for that known gap) — callers must fall back to buildLabelQr() in
  /// that case, not assume this is always present.
  final String? unitSerial;

  const LabelingItemEntity({
    required this.id,
    required this.batchId,
    this.batchTitle,
    this.machineId,
    this.machineName,
    this.clientName,
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
    this.isTypePrintable = true,
    this.edgeCode,
    this.unitSerial,
  });

  String get sizeLabel {
    if (sizeLength == null || sizeWidth == null) return '—';
    return '${sizeWidth}×$sizeLength';
  }

  int get netTarget => (plannedQuantity - defectQuantity).clamp(0, plannedQuantity);

  int get remainingQuantity => (netTarget - producedQuantity).clamp(0, netTarget);

  bool get isFullyLabeled => producedQuantity >= netTarget;

  LabelingItemEntity copyWith({
    int? producedQuantity,
    int? defectQuantity,
    String? unitSerial,
  }) {
    return LabelingItemEntity(
      id: id,
      batchId: batchId,
      batchTitle: batchTitle,
      machineId: machineId,
      machineName: machineName,
      clientName: clientName,
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
      isTypePrintable: isTypePrintable,
      edgeCode: edgeCode,
      unitSerial: unitSerial ?? this.unitSerial,
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
