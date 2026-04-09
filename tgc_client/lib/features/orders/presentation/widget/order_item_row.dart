import 'package:flutter/material.dart';

import '../../../products/domain/entities/product_color_entity.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';

/// View-layer model that holds the mutable state for a single line item
/// in the "add order" form.
class OrderItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  ProductEntity? selectedProduct;
  ProductColorEntity? selectedColor;
  ProductSizeEntity? selectedSize;
  final quantityCtrl = TextEditingController(text: '1');

  void dispose() {
    quantityCtrl.dispose();
  }

  /// Returns null if the row is empty (no product selected).
  bool get isFilled => selectedProduct != null && selectedColor != null;

  String get label {
    if (selectedProduct == null) return 'Mahsulot tanlanmagan';
    final parts = <String>[selectedProduct!.name];
    if (selectedColor != null) parts.add(selectedColor!.colorName);
    if (selectedSize != null) parts.add(selectedSize!.dimensions);
    return parts.join(' / ');
  }
}
