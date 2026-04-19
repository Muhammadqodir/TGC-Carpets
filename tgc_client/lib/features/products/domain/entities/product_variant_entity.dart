import 'package:equatable/equatable.dart';

class ProductVariantEntity extends Equatable {
  final int id;
  final String? barcodeValue;
  final String? skuCode;
  final int productColorId;
  final int? productId;
  final String? productName;
  final String? colorName;
  final String? productUnit;
  final int? sizeLength;
  final int? sizeWidth;

  const ProductVariantEntity({
    required this.id,
    this.barcodeValue,
    this.skuCode,
    required this.productColorId,
    this.productId,
    this.productName,
    this.colorName,
    this.productUnit,
    this.sizeLength,
    this.sizeWidth,
  });

  /// Human-readable size label, e.g. "200x300".
  String? get sizeDimensions =>
      sizeLength != null && sizeWidth != null ? '${sizeLength}x$sizeWidth' : null;

  /// Full label combining product name, color, and size, e.g. "Carpet Pro (krem) 200x300".
  String get label {
    final size = sizeDimensions;
    final color = colorName != null ? ' ($colorName)' : '';
    final sizeStr = size != null ? ' $size' : '';
    return '${productName ?? '#$id'}$color$sizeStr';
  }

  @override
  List<Object?> get props => [id, barcodeValue, skuCode, productColorId, sizeLength, sizeWidth];
}
