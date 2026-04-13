import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../products/data/models/product_color_model.dart';
import '../../../products/data/models/product_model.dart';

import '../../../products/data/models/product_size_model.dart';

import '../../../products/domain/entities/product_color_entity.dart';
import '../../../products/domain/entities/product_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../presentation/widgets/warehouse_document_form_controller.dart';
import '../../presentation/widgets/warehouse_item_row.dart';

/// Persists the in-progress "add warehouse document" draft so that:
///   • Navigating away / closing the page does NOT lose data.
///   • The draft is cleared only when the document is successfully submitted.
///
/// Storage key is versioned (v1) — bump to wipe stale drafts after
/// breaking schema changes.
class WarehouseDocumentDraftService {
  static const _key = 'wh_doc_draft_v2';

  final SharedPreferences _prefs;

  WarehouseDocumentDraftService(this._prefs);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Serialises the current controller state and stores it.
  Future<void> save(WarehouseDocumentFormController ctrl) async {
    final payload = {
      'notes': ctrl.notesCtrl.text,
      'items': ctrl.items
          .map((r) => {
                'product':
                    r.selectedProduct != null ? _productToJson(r.selectedProduct!) : null,
                'color':
                    r.selectedColor != null ? _colorToJson(r.selectedColor!) : null,
                'size': r.selectedSize != null ? _sizeToJson(r.selectedSize!) : null,
                'quantity': r.quantityCtrl.text,
                'notes': r.notesCtrl.text,
                // Prefill fields (batch-imported rows)
                'prefilled_color_id': r.prefilledColorId,
                'prefilled_size_id': r.prefilledSizeId,
                'prefilled_product_id': r.prefilledProductId,
                'prefilled_product_name': r.prefilledProductName,
                'prefilled_color_name': r.prefilledColorName,
                'prefilled_color_image_url': r.prefilledColorImageUrl,
                'prefilled_product_type_id': r.prefilledProductTypeId,
                'prefilled_size_length': r.prefilledSizeLength,
                'prefilled_size_width': r.prefilledSizeWidth,
                'prefilled_quality_name': r.prefilledQualityName,
                'prefilled_type_name': r.prefilledTypeName,
                // Source tracking
                'source_batch_id': r.sourceBatchId,
                'source_batch_item_id': r.sourceBatchItemId,
                'source_batch_title': r.sourceBatchTitle,
                'produced_quantity': r.producedQuantity,
              })
          .toList(),
    };
    await _prefs.setString(_key, jsonEncode(payload));
  }

  /// Restores a previously saved draft into [ctrl].
  /// Returns `true` if a draft was found and applied, `false` otherwise.
  Future<bool> restore(WarehouseDocumentFormController ctrl) async {
    final raw = _prefs.getString(_key);
    if (raw == null) return false;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final rawItems = (data['items'] as List<dynamic>?) ?? [];
      final notes = (data['notes'] as String?) ?? '';

      final rows = <WarehouseItemRow>[];
      for (final rawItem in rawItems) {
        final item = rawItem as Map<String, dynamic>;

        final row = WarehouseItemRow(
          prefilledColorId: item['prefilled_color_id'] as int?,
          prefilledSizeId: item['prefilled_size_id'] as int?,
          prefilledProductId: item['prefilled_product_id'] as int?,
          prefilledProductName: item['prefilled_product_name'] as String?,
          prefilledColorName: item['prefilled_color_name'] as String?,
          prefilledColorImageUrl: item['prefilled_color_image_url'] as String?,
          prefilledProductTypeId: item['prefilled_product_type_id'] as int?,
          prefilledSizeLength: item['prefilled_size_length'] as int?,
          prefilledSizeWidth: item['prefilled_size_width'] as int?,
          prefilledQualityName: item['prefilled_quality_name'] as String?,
          prefilledTypeName: item['prefilled_type_name'] as String?,
          sourceBatchId: item['source_batch_id'] as int?,
          sourceBatchItemId: item['source_batch_item_id'] as int?,
          sourceBatchTitle: item['source_batch_title'] as String?,
          producedQuantity: item['produced_quantity'] as int?,
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

        row.quantityCtrl.text = (item['quantity'] as String?) ?? '';
        row.notesCtrl.text = (item['notes'] as String?) ?? '';
        rows.add(row);
      }

      if (rows.isEmpty) return false;
      ctrl.restoreFrom(newItems: rows, notes: notes);
      return true;
    } catch (_) {
      // Corrupted / incompatible draft — silently ignore
      await clear();
      return false;
    }
  }

  /// Removes the stored draft (call after successful submission).
  Future<void> clear() => _prefs.remove(_key);

  // ── Serialisation helpers ─────────────────────────────────────────────────

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
            'density': p.productQuality!.density,
          },
        'product_colors':
            p.productColors.map(_colorToJson).toList(),
      };

  static Map<String, dynamic> _colorToJson(ProductColorEntity c) => {
        'id': c.id,
        'color': {'id': c.colorId, 'name': c.colorName},
        'image_url': c.imageUrl,
      };

  static Map<String, dynamic> _sizeToJson(ProductSizeEntity s) => {
        'id': s.id,
        'length': s.length,
        'width': s.width,
        'product_type_id': s.productTypeId,
      };

  static ProductEntity _productFromJson(Map<String, dynamic> json) =>
      ProductModel.fromJson({
        ...json,
        // Ensure nested fields are present even if stored without them
        'product_colors': json['product_colors'] ?? [],
      });
}
