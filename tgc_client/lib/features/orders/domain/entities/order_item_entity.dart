import 'package:equatable/equatable.dart';

class OrderItemEntity extends Equatable {
  final int id;
  final int variantId;
  final String? variantSku;
  final String? variantBarcode;
  final int? productId;
  final String productName;
  final String? colorName;
  /// The color image URL returned by the server (product_color.image_url).
  final String? colorImageUrl;
  final int? sizeLength;
  final int? sizeWidth;
  final String? productUnit;
  final int quantity;
  /// The product_color.id — required when re-submitting an edit.
  final int productColorId;
  /// The product_size.id — required when the variant has a size.
  final int? productSizeId;
  /// product.product_type_id — needed to open the size picker in edit mode.
  final int? productTypeId;
  /// product.productQuality.quality_name — shown in the Sifat column.
  final String? qualityName;

  const OrderItemEntity({
    required this.id,
    required this.variantId,
    this.variantSku,
    this.variantBarcode,
    required this.productId,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.sizeLength,
    this.sizeWidth,
    this.productUnit,
    required this.quantity,
    required this.productColorId,
    this.productSizeId,
    this.productTypeId,
    this.qualityName,
  });

  String get variantLabel {
    final parts = <String>[productName];
    if (colorName != null) parts.add(colorName!);
    if (sizeLength != null && sizeWidth != null) {
      parts.add('${sizeLength}x$sizeWidth');
    }
    return parts.join(' / ');
  }

  @override
  List<Object?> get props => [
        id,
        variantId,
        variantSku,
        variantBarcode,
        productId,
        productName,
        colorName,
        colorImageUrl,
        sizeLength,
        sizeWidth,
        productUnit,
        quantity,
        productColorId,
        productSizeId,
        productTypeId,
        qualityName,
      ];
}
