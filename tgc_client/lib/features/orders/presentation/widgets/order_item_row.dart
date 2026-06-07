import 'package:flutter/material.dart';

import '../../../products/domain/entities/product_color_entity.dart';
import '../../../products/domain/entities/product_edge_entity.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';

/// View-layer model that holds the mutable state for a single line item
/// in the add/edit order form.
///
/// In edit mode, rows are pre-populated with [prefilledColorId] /
/// [prefilledSizeId] etc. so existing items can be displayed and edited
/// without fetching full entity objects upfront.
class OrderItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  ProductEntity? selectedProduct;
  ProductColorEntity? selectedColor;
  ProductSizeEntity? selectedSize;
  ProductEdgeEntity? selectedEdge;
  final TextEditingController quantityCtrl;

  // ── Prefill data (edit mode, from server) ─────────────────────────────────

  /// product_color.id – used for submission when no entity has been picked yet.
  final int? prefilledColorId;

  /// product_size.id – used for submission when no entity has been picked yet.
  final int? prefilledSizeId;

  /// product_edge.id – used for submission when no entity has been picked yet.
  final int? prefilledEdgeId;

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

  /// Edge code for display when no entity has been selected yet.
  final String? prefilledEdgeCode;

  OrderItemRow({
    this.prefilledColorId,
    this.prefilledSizeId,
    this.prefilledEdgeId,
    this.prefilledProductName,
    this.prefilledColorName,
    this.prefilledColorImageUrl,
    this.prefilledQualityName,
    this.prefilledProductTypeName,
    this.prefilledProductTypeId,
    this.prefilledSizeLength,
    this.prefilledSizeWidth,
    this.prefilledEdgeCode,
    int initialQuantity = 1,
  }) : quantityCtrl = TextEditingController(text: '$initialQuantity');

  void dispose() => quantityCtrl.dispose();

  /// True when the row has enough data to be submitted.
  bool get isFilled => selectedProduct != null || prefilledColorId != null;

  /// Resolved edge ID — from selected entity or prefill.
  int? get effectiveEdgeId => selectedEdge?.id ?? prefilledEdgeId;

  /// Display string for size, derived from prefill integers.
  String? get prefilledSizeDimensions =>
      prefilledSizeLength != null && prefilledSizeWidth != null
          ? '$prefilledSizeWidth×$prefilledSizeLength'
          : null;

  String get label {
    if (selectedProduct != null) {
      final parts = <String>[selectedProduct!.name];
      if (selectedColor != null) parts.add(selectedColor!.colorName);
      if (selectedSize != null) parts.add(selectedSize!.dimensions);
      if (selectedEdge != null) parts.add('[${selectedEdge!.code}]');
      return parts.join(' / ');
    }
    if (prefilledProductName != null) {
      final parts = <String>[prefilledProductName!];
      if (prefilledColorName != null) parts.add(prefilledColorName!);
      final dim = prefilledSizeDimensions;
      if (dim != null) parts.add(dim);
      if (prefilledEdgeCode != null) parts.add('[$prefilledEdgeCode]');
      return parts.join(' / ');
    }
    return 'Mahsulot tanlanmagan';
  }
}
