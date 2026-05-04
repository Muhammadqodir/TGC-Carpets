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
  });

  String get sizeLabel {
    if (sizeLength == null || sizeWidth == null) return '—';
    return '${sizeWidth}×$sizeLength';
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
      ];
}
