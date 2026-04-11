import 'package:flutter/material.dart';

import '../../../orders/domain/entities/order_entity.dart';
import '../../../orders/domain/entities/order_item_entity.dart';
import '../../domain/entities/production_batch_entity.dart';
import 'batch_item_row.dart';

/// Holds mutable UI state for the production batch form.
/// Mirrors the sentinel-row pattern from [OrderFormController].
class ProductionBatchFormController extends ChangeNotifier {
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController notesCtrl = TextEditingController();

  final List<BatchItemRow> _items = [BatchItemRow()];

  List<BatchItemRow> get items => List.unmodifiable(_items);

  // ── Row mutations ─────────────────────────────────────────────────────────

  void updateRow(BatchItemRow row, {bool notify = true}) {
    _ensureSentinel();
    if (notify) notifyListeners();
  }

  void removeRow(BatchItemRow row) {
    if (_items.length <= 1) return;
    _items.remove(row);
    row.dispose();
    _ensureSentinel();
    notifyListeners();
  }

  /// Called when the user picks a product/color/size on the sentinel row.
  /// Promotes the sentinel to a real row and appends a fresh sentinel.
  void promoteIfSentinel(BatchItemRow row) {
    final isSentinel = _items.last == row;
    if (isSentinel && row.isFilled) {
      _items.add(BatchItemRow());
      notifyListeners();
    }
  }
  /// Replaces all current rows with rows built from an existing [batch]'s
  /// items. Called once on entering edit mode.
  void loadFromBatch(ProductionBatchEntity batch) {
    for (final row in _items) {
      row.dispose();
    }
    _items.clear();
    for (final item in batch.items) {
      _items.add(BatchItemRow.fromBatchItem(item));
    }
    _ensureSentinel();
    notifyListeners();
  }

  /// Inserts rows imported from [order]'s [items].
  /// Any duplicate variant (same colorId + sizeId) already in the list is
  /// skipped to avoid duplicates.
  void addRowsFromOrder(OrderEntity order, List<OrderItemEntity> items) {
    // Remove trailing sentinel temporarily
    if (_items.isNotEmpty && !_items.last.isFilled) {
      final sentinel = _items.removeLast();
      sentinel.dispose();
    }

    for (final item in items) {
      final alreadyExists = _items.any((r) {
        final rColorId = r.selectedColor?.id ?? r.prefilledColorId;
        final rSizeId = r.selectedSize?.id ?? r.prefilledSizeId;
        return rColorId == item.productColorId &&
            rSizeId == item.productSizeId;
      });
      if (!alreadyExists) {
        _items.add(BatchItemRow.fromOrderItem(item,
              orderId: order.id,
              clientName: order.clientShopName ?? order.userName));
      }
    }

    _ensureSentinel();
    notifyListeners();
  }
  // ── Build submission payload ───────────────────────────────────────────────

  /// Derives the batch type from the current filled rows:
  /// - all from orders  → `'by_order'`
  /// - all manual       → `'for_stock'`
  /// - mixed            → `'mixed'`
  /// Falls back to `'for_stock'` when there are no filled rows yet.
  String get computedType {
    final filled = _items.where((r) => r.isFilled).toList();
    if (filled.isEmpty) return 'for_stock';
    final fromOrder = filled.where((r) => r.sourceOrderItemId != null).length;
    if (fromOrder == filled.length) return 'by_order';
    if (fromOrder == 0) return 'for_stock';
    return 'mixed';
  }

  List<Map<String, dynamic>> buildItemsPayload() {
    return _items
        .where((r) => r.isFilled)
        .where((r) =>
            r.selectedColor != null ||
            r.prefilledColorId != null)
        .map((r) {
          final colorId =
              r.selectedColor?.id ?? r.prefilledColorId;
          final sizeId =
              r.selectedSize?.id ?? r.prefilledSizeId;
          final qty =
              int.tryParse(r.quantityCtrl.text.trim()) ?? 1;
          return {
            'product_color_id': colorId,
            'product_size_id': sizeId,
            'planned_quantity': qty,
            'source_type': r.sourceOrderItemId != null ? 'order_item' : 'manual',
            if (r.sourceOrderItemId != null)
              'source_order_item_id': r.sourceOrderItemId,
          };
        })
        .toList();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void _ensureSentinel() {
    if (_items.isEmpty || _items.last.isFilled) {
      _items.add(BatchItemRow());
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    notesCtrl.dispose();
    for (final row in _items) {
      row.dispose();
    }
    super.dispose();
  }
}
