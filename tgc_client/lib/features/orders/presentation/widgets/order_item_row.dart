import 'package:flutter/material.dart';

import '../../../products/domain/entities/product_color_entity.dart';
import '../../../products/domain/entities/product_entity.dart';

/// View-layer model that holds the mutable state for a single line item
/// in the add/edit order form.
///
/// In edit mode, rows are pre-populated with [prefilledColorId] /
/// [prefilledSizeLength]/[prefilledSizeWidth] etc. so existing items can be
/// displayed and edited without fetching full entity objects upfront.
class OrderItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  ProductEntity? selectedProduct;
  ProductColorEntity? selectedColor;
  int? selectedLength;
  int? selectedWidth;
  final TextEditingController quantityCtrl;

  // ── Prefill data (edit mode, from server) ─────────────────────────────────

  /// product_color.id – used for submission when no entity has been picked yet.
  final int? prefilledColorId;

  final String? prefilledProductName;
  final String? prefilledColorName;
  /// Color thumbnail URL from the server.
  final String? prefilledColorImageUrl;

  /// product.productQuality.quality_name — shown in the Sifat column.
  final String? prefilledQualityName;
  /// product.productType.type — shown in the Tur column.
  final String? prefilledProductTypeName;

  /// product.product_type_id — when set, a size picker is shown even for prefilled rows.
  final int? prefilledProductTypeId;

  /// Stored as separate ints so m² can be calculated without the size entity.
  final int? prefilledSizeLength;
  final int? prefilledSizeWidth;

  OrderItemRow({
    this.prefilledColorId,
    this.prefilledProductName,
    this.prefilledColorName,
    this.prefilledColorImageUrl,
    this.prefilledQualityName,
    this.prefilledProductTypeName,
    this.prefilledProductTypeId,
    this.prefilledSizeLength,
    this.prefilledSizeWidth,
    int initialQuantity = 1,
  }) : quantityCtrl = TextEditingController(text: '$initialQuantity');

  void dispose() => quantityCtrl.dispose();

  /// True when the row has enough data to be submitted.
  /// Either new entity data or pre-existing server IDs.
  bool get isFilled => selectedProduct != null || prefilledColorId != null;

  /// Effective length (selected takes priority over prefilled).
  int? get effectiveLength => selectedLength ?? prefilledSizeLength;

  /// Effective width (selected takes priority over prefilled).
  int? get effectiveWidth => selectedWidth ?? prefilledSizeWidth;

  /// Display string for size, derived from effective integers.
  String? get sizeDimensions {
    final l = effectiveLength;
    final w = effectiveWidth;
    return (l != null && w != null) ? '${l}x$w' : null;
  }

  String get label {
    if (selectedProduct != null) {
      final parts = <String>[selectedProduct!.name];
      if (selectedColor != null) parts.add(selectedColor!.colorName);
      final dim = sizeDimensions;
      if (dim != null) parts.add(dim);
      return parts.join(' / ');
    }
    if (prefilledProductName != null) {
      final parts = <String>[prefilledProductName!];
      if (prefilledColorName != null) parts.add(prefilledColorName!);
      final dim = sizeDimensions;
      if (dim != null) parts.add(dim);
      return parts.join(' / ');
    }
    return 'Mahsulot tanlanmagan';
  }
}
