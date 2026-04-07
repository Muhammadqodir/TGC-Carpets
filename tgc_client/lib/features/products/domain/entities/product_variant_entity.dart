import 'package:equatable/equatable.dart';

class ProductVariantEntity extends Equatable {
  final int id;
  final String? barcodeValue;
  final int productId;
  final String? productName;
  final String? productSkuCode;
  final String? productUnit;
  final int? productSizeId;
  final int? sizeLength;
  final int? sizeWidth;

  const ProductVariantEntity({
    required this.id,
    this.barcodeValue,
    required this.productId,
    this.productName,
    this.productSkuCode,
    this.productUnit,
    this.productSizeId,
    this.sizeLength,
    this.sizeWidth,
  });

  /// Human-readable size label, e.g. "200x300".
  String? get sizeDimensions =>
      sizeLength != null && sizeWidth != null ? '${sizeLength}x$sizeWidth' : null;

  /// Full label combining product name and size, e.g. "Carpet Pro 200x300".
  String get label {
    final size = sizeDimensions;
    return size != null ? '$productName $size' : (productName ?? '#$id');
  }

  @override
  List<Object?> get props => [id, barcodeValue, productId, productSizeId];
}
