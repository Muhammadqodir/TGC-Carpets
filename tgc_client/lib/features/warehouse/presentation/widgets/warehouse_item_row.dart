import 'package:flutter/material.dart';

import '../../../products/domain/entities/product_color_entity.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';

/// View-layer model that holds the mutable state for a single line item in
/// the "add warehouse document" form (both mobile and desktop variants).
class WarehouseItemRow {
  static int _counter = 0;
  final int id = ++_counter;

  ProductEntity? selectedProduct;
  ProductColorEntity? selectedColor;
  ProductSizeEntity? selectedSize;
  final quantityCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  void dispose() {
    quantityCtrl.dispose();
    notesCtrl.dispose();
  }
}
