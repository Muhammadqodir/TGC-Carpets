import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../products/data/models/product_color_model.dart';
import '../../../products/data/models/product_model.dart';
import '../../../products/data/models/product_size_model.dart';
import '../../../products/domain/entities/product_color_entity.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../presentation/widgets/order_form_controller.dart';
import '../../presentation/widgets/order_item_row.dart';

/// Persists the in-progress "add order" draft so that:
///   • Navigating away / closing the page does NOT lose data.
///   • The draft is cleared only when the order is successfully submitted.
///
/// Storage key is versioned (v1) — bump to wipe stale drafts after
/// breaking schema changes.
class OrderFormDraftService {
  static const _key = 'order_form_draft_v1';

  final SharedPreferences _prefs;

  OrderFormDraftService(this._prefs);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Serialises the current controller state and stores it.
  Future<void> save(OrderFormController ctrl, {
    DateTime? orderDate,
    int? clientId,
    String? clientShopName,
  }) async {
    print('DEBUG: save() called with ${ctrl.filledItems.length} filled items');
    final payload = {
      'notes': ctrl.notesCtrl.text,
      'order_date': orderDate?.toIso8601String(),
      'client_id': clientId,
      'client_shop_name': clientShopName,
      'is_matrix_mode': ctrl.isMatrixMode,
      'items': ctrl.filledItems
          .map((r) {
                final qty = r.quantityCtrl.text;
                print('DEBUG: Saving item - product: ${r.selectedProduct?.name}, color: ${r.selectedColor?.colorName}, quantity: "$qty"');
                return {
                  'product':
                      r.selectedProduct != null ? _productToJson(r.selectedProduct!) : null,
                  'color':
                      r.selectedColor != null ? _colorToJson(r.selectedColor!) : null,
                  'size': r.selectedSize != null ? _sizeToJson(r.selectedSize!) : null,
                  'quantity': qty,
                  // Prefill fields (edit mode rows)
                  'prefilled_color_id': r.prefilledColorId,
                  'prefilled_size_id': r.prefilledSizeId,
                  'prefilled_product_name': r.prefilledProductName,
                  'prefilled_color_name': r.prefilledColorName,
                  'prefilled_color_image_url': r.prefilledColorImageUrl,
                  'prefilled_quality_name': r.prefilledQualityName,
                  'prefilled_product_type_name': r.prefilledProductTypeName,
                  'prefilled_product_type_id': r.prefilledProductTypeId,
                  'prefilled_size_length': r.prefilledSizeLength,
                  'prefilled_size_width': r.prefilledSizeWidth,
                };
              })
          .toList(),
      // Matrix mode data
      if (ctrl.isMatrixMode) 'matrix_size_columns': ctrl.matrixSizeColumns
          .map((s) => _sizeToJson(s))
          .toList(),
      if (ctrl.isMatrixMode) 'matrix_quantities': _serializeMatrixQuantities(ctrl),
    };
    final jsonStr = jsonEncode(payload);
    print('DEBUG: Saving draft, JSON length: ${jsonStr.length} bytes');
    await _prefs.setString(_key, jsonStr);
    print('DEBUG: Draft saved successfully');
  }

  /// Restores a previously saved draft into [ctrl].
  /// Returns [DraftData] if a draft was found, null otherwise.
  Future<DraftData?> restore() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final notes = (data['notes'] as String?) ?? '';
      final orderDateStr = data['order_date'] as String?;
      final clientId = data['client_id'] as int?;
      final clientShopName = data['client_shop_name'] as String?;
      final isMatrixMode = data['is_matrix_mode'] as bool? ?? false;

      final rows = <OrderItemRow>[];
      for (final rawItem in rawItems) {
        final item = rawItem as Map<String, dynamic>;

        // Parse quantity first so we can pass it to the constructor
        final quantityStr = (item['quantity'] as String?) ?? '1';
        final initialQty = int.tryParse(quantityStr) ?? 1;
        print('DEBUG: Restoring item with quantity string: $quantityStr, parsed: $initialQty');

        final row = OrderItemRow(
          prefilledColorId: item['prefilled_color_id'] as int?,
          prefilledSizeId: item['prefilled_size_id'] as int?,
          prefilledProductName: item['prefilled_product_name'] as String?,
          prefilledColorName: item['prefilled_color_name'] as String?,
          prefilledColorImageUrl: item['prefilled_color_image_url'] as String?,
          prefilledQualityName: item['prefilled_quality_name'] as String?,
          prefilledProductTypeName: item['prefilled_product_type_name'] as String?,
          prefilledProductTypeId: item['prefilled_product_type_id'] as int?,
          prefilledSizeLength: item['prefilled_size_length'] as int?,
          prefilledSizeWidth: item['prefilled_size_width'] as int?,
          initialQuantity: initialQty,  // Pass the quantity to constructor!
        );

        final rawProduct = item['product'] as Map<String, dynamic>?;
        if (rawProduct != null) {
          row.selectedProduct = _productFromJson(rawProduct);
        }

        final rawColor = item['color'] as Map<String, dynamic>?;
        if (rawColor != null) {
          row.selectedColor = ProductColorModel.fromJson(rawColor);
        }

        final rawSize = item['size'] as Map<String, dynamic>?;
        if (rawSize != null) {
          row.selectedSize = ProductSizeModel.fromJson(rawSize);
        }

        print('DEBUG: After creating row, quantityCtrl.text = ${row.quantityCtrl.text}');
        rows.add(row);
      }

      List<ProductSizeEntity>? matrixSizeColumns;
      Map<String, int>? matrixQuantities;
      
      if (isMatrixMode) {
        final rawSizes = (data['matrix_size_columns'] as List<dynamic>?) ?? [];
        matrixSizeColumns = rawSizes
            .map((raw) => ProductSizeModel.fromJson(raw as Map<String, dynamic>))
            .toList();
        
        final rawQty = data['matrix_quantities'] as Map<String, dynamic>?;
        if (rawQty != null) {
          matrixQuantities = rawQty.map((k, v) => MapEntry(k, v as int));
        }
      }

      if (rows.isEmpty) return null;

      return DraftData(
        rows: rows,
        notes: notes,
        orderDate: orderDateStr != null ? DateTime.tryParse(orderDateStr) : null,
        clientId: clientId,
        clientShopName: clientShopName,
        isMatrixMode: isMatrixMode,
        matrixSizeColumns: matrixSizeColumns,
        matrixQuantities: matrixQuantities,
      );
    } catch (_) {
      // Corrupted / incompatible draft — silently ignore
      await clear();
      return null;
    }
  }

  /// Removes the stored draft (call after successful submission).
  Future<void> clear() => _prefs.remove(_key);

  // ── Serialisation helpers ─────────────────────────────────────────────────

  Map<String, int> _serializeMatrixQuantities(OrderFormController ctrl) {
    final result = <String, int>{};
    for (final colorId in ctrl.getUniqueItems()
        .map((r) => r.selectedColor?.id ?? r.prefilledColorId)
        .whereType<int>()) {
      for (final size in ctrl.matrixSizeColumns) {
        final key = '${colorId}_${size.id}';
        final cellCtrl = ctrl.matrixCellCtrl(colorId, size.id);
        final qty = int.tryParse(cellCtrl.text.trim()) ?? 0;
        if (qty > 0) {
          result[key] = qty;
        }
      }
    }
    return result;
  }

  static Map<String, dynamic> _productToJson(ProductEntity p) => {
        'id': p.id,
        'uuid': p.uuid,
        'name': p.name,
        'product_type_id': p.productTypeId,
        'product_quality_id': p.productQualityId,
        'unit': p.unit,
        'status': p.status,
        'created_at': p.createdAt.toIso8601String(),
        'updated_at': p.updatedAt.toIso8601String(),
        if (p.productType != null)
          'product_type': {
            'id': p.productType!.id,
            'type': p.productType!.type,
          },
        if (p.productQuality != null)
          'product_quality': {
            'id': p.productQuality!.id,
            'quality_name': p.productQuality!.qualityName,
          },
      };

  static ProductEntity _productFromJson(Map<String, dynamic> json) =>
      ProductModel.fromJson(json);

  static Map<String, dynamic> _colorToJson(ProductColorEntity c) => {
        'id': c.id,
        'color': {
          'id': c.colorId,
          'name': c.colorName,
        },
        'image_url': c.imageUrl,
      };

  static Map<String, dynamic> _sizeToJson(ProductSizeEntity s) => {
        'id': s.id,
        'product_type_id': s.productTypeId,
        'length': s.length,
        'width': s.width,
      };
}

/// Encapsulates all restored draft data.
class DraftData {
  final List<OrderItemRow> rows;
  final String notes;
  final DateTime? orderDate;
  final int? clientId;
  final String? clientShopName;
  final bool isMatrixMode;
  final List<ProductSizeEntity>? matrixSizeColumns;
  final Map<String, int>? matrixQuantities;

  DraftData({
    required this.rows,
    required this.notes,
    this.orderDate,
    this.clientId,
    this.clientShopName,
    this.isMatrixMode = false,
    this.matrixSizeColumns,
    this.matrixQuantities,
  });
}
