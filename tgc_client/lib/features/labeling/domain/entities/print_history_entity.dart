import 'package:equatable/equatable.dart';

class PrintHistoryEntity extends Equatable {
  final int variantId;
  final String productName;
  final String? colorName;
  final String? colorImageUrl;
  final int? sizeLength;
  final int? sizeWidth;
  final String? qualityName;
  final String? productTypeName;
  final String? variantBarcode;
  final int batchId;
  final String? batchTitle;
  final int printedAt; // Unix timestamp

  /// The production_batch_item id — required to rebuild a QR code the
  /// backend can actually resolve (`P{batchId} I{itemId}`). Nullable because
  /// history entries persisted before this field existed won't have it; such
  /// legacy entries can no longer be reprinted with a correct QR.
  final int? itemId;

  /// The client the carpet is made for, 0 for stock. Null on entries saved
  /// before labels carried the print code; those reprint without it rather
  /// than with a client they may not belong to.
  final int? clientId;

  /// The unique number on this label, which a reprint repeats. Null on entries
  /// saved before labels had numbers; those reprint without one, like the
  /// label already on that carpet.
  final String? carpetNumber;

  /// The real length printed on this Kovrolin label, in cm, which a reprint
  /// repeats. Null for a fixed-size carpet.
  final int? actualLengthCm;

  const PrintHistoryEntity({
    required this.variantId,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.sizeLength,
    this.sizeWidth,
    this.qualityName,
    this.productTypeName,
    this.variantBarcode,
    required this.batchId,
    this.batchTitle,
    required this.printedAt,
    this.itemId,
    this.clientId,
    this.carpetNumber,
    this.actualLengthCm,
  });

  /// The size as printed: the real length when the label carried one.
  String get sizeLabel {
    final length = actualLengthCm ?? sizeLength;
    if (length == null || sizeWidth == null) return '—';
    return '${sizeWidth}×$length';
  }

  Map<String, dynamic> toJson() {
    return {
      'variantId': variantId,
      'productName': productName,
      'colorName': colorName,
      'colorImageUrl': colorImageUrl,
      'sizeLength': sizeLength,
      'sizeWidth': sizeWidth,
      'qualityName': qualityName,
      'productTypeName': productTypeName,
      'variantBarcode': variantBarcode,
      'batchId': batchId,
      'batchTitle': batchTitle,
      'printedAt': printedAt,
      'itemId': itemId,
      'clientId': clientId,
      'carpetNumber': carpetNumber,
      if (actualLengthCm != null) 'actualLengthCm': actualLengthCm,
    };
  }

  factory PrintHistoryEntity.fromJson(Map<String, dynamic> json) {
    return PrintHistoryEntity(
      variantId: json['variantId'] as int,
      productName: json['productName'] as String,
      colorName: json['colorName'] as String?,
      colorImageUrl: json['colorImageUrl'] as String?,
      sizeLength: json['sizeLength'] as int?,
      sizeWidth: json['sizeWidth'] as int?,
      qualityName: json['qualityName'] as String?,
      productTypeName: json['productTypeName'] as String?,
      variantBarcode: json['variantBarcode'] as String?,
      batchId: json['batchId'] as int,
      batchTitle: json['batchTitle'] as String?,
      printedAt: json['printedAt'] as int,
      itemId: json['itemId'] as int?,
      clientId: json['clientId'] as int?,
      carpetNumber: json['carpetNumber'] as String?,
      actualLengthCm: json['actualLengthCm'] as int?,
    );
  }

  @override
  List<Object?> get props => [
        variantId,
        productName,
        colorName,
        sizeLength,
        sizeWidth,
        qualityName,
        productTypeName,
        printedAt,
        itemId,
        clientId,
        carpetNumber,
        actualLengthCm,
      ];
}
