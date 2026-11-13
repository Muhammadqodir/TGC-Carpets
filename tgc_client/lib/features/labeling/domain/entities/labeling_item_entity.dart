import 'package:equatable/equatable.dart';

class LabelingItemEntity extends Equatable {
  final int id;
  final int batchId;
  final String? batchTitle;
  final int? machineId;
  final String? machineName;

  /// The client the carpet is made for; null for a carpet made for stock.
  final int? clientId;
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

  /// The type's carpets come off the machine at a different length each
  /// time (Kovrolin): the real length is typed in before every label.
  final bool hasVariableLength;
  final String? edgeCode;

  /// The real length of the carpet this label is for, in cm, typed in just
  /// before printing. Null everywhere else: the item as loaded from the
  /// server names only the size's nominal length.
  final int? actualLengthCm;

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
    this.clientId,
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
    this.hasVariableLength = false,
    this.edgeCode,
    this.unitSerial,
    this.actualLengthCm,
  });

  /// The size as printed: the real length when one was typed in.
  String get sizeLabel {
    final length = actualLengthCm ?? sizeLength;
    if (length == null || sizeWidth == null) return '—';
    return '${sizeWidth}×$length';
  }

  /// The size the line was planned at, whatever a label says.
  String get nominalSizeLabel {
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
    int? actualLengthCm,
  }) {
    return LabelingItemEntity(
      id: id,
      batchId: batchId,
      batchTitle: batchTitle,
      machineId: machineId,
      machineName: machineName,
      clientId: clientId,
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
      hasVariableLength: hasVariableLength,
      edgeCode: edgeCode,
      unitSerial: unitSerial ?? this.unitSerial,
      actualLengthCm: actualLengthCm ?? this.actualLengthCm,
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
