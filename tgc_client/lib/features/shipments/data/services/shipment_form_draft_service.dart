import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../clients/domain/entities/client_entity.dart';
import '../../presentation/widgets/shipment_form_controller.dart';
import '../../presentation/widgets/shipment_item_row.dart';

/// Persists the in-progress "add shipment" draft so that:
///   • Navigating away / closing the page does NOT lose data.
///   • The draft is cleared only on a successful submit, or when the user
///     hits the clear button.
///
/// Storage key is versioned (v1) — bump to wipe stale drafts after
/// breaking schema changes.
class ShipmentFormDraftService {
  static const _key = 'shipment_form_draft_v1';

  final SharedPreferences _prefs;

  ShipmentFormDraftService(this._prefs);

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Serialises the current form state and stores it.
  ///
  /// [shipmentDate] must be null unless the user actually picked a date:
  /// replaying "today" out of a draft written yesterday would silently
  /// back-date a real shipment.
  Future<void> save(
    ShipmentFormController ctrl, {
    ClientEntity? client,
    DateTime? shipmentDate,
  }) async {
    final payload = {
      'notes': ctrl.notesCtrl.text,
      'shipment_date': shipmentDate?.toIso8601String(),
      'client': client != null ? _clientToJson(client) : null,
      // Every row, not just the filled ones — a row whose quantity box is
      // momentarily blank is still a carpet the user put on the lorry.
      'items': ctrl.items.map(_rowToJson).toList(),
    };
    await _prefs.setString(_key, jsonEncode(payload));
  }

  /// Reads back a previously saved draft.
  /// Returns null when there is nothing worth restoring.
  Future<ShipmentDraftData?> restore() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final notes = (data['notes'] as String?) ?? '';
      final rawDate = data['shipment_date'] as String?;
      final rawClient = data['client'] as Map<String, dynamic>?;
      final rawItems = (data['items'] as List<dynamic>?) ?? [];

      final rows = rawItems
          .map((raw) => _rowFromJson(raw as Map<String, dynamic>))
          .toList();

      final client = rawClient != null ? _clientFromJson(rawClient) : null;

      // Nothing filled in — treat it as no draft at all so the page opens
      // blank instead of flashing a restore it did not need.
      if (rows.isEmpty && client == null && notes.isEmpty) return null;

      return ShipmentDraftData(
        rows: rows,
        notes: notes,
        client: client,
        shipmentDate: rawDate != null ? DateTime.tryParse(rawDate) : null,
      );
    } catch (_) {
      // Corrupted / incompatible draft — drop it and open blank.
      await clear();
      return null;
    }
  }

  /// Removes the stored draft (call after a successful submit).
  Future<void> clear() => _prefs.remove(_key);

  // ── Serialisation helpers ───────────────────────────────────────────────────

  static Map<String, dynamic> _rowToJson(ShipmentItemRow r) => {
        'order_item_id': r.orderItemId,
        'variant_id': r.variantId,
        'scanned': r.scanned,
        'scanned_batch_item_ids': r.scannedBatchItemIds,
        'produced_for_clients': r.producedForClients.toList(),
        'product_name': r.productName,
        'color_name': r.colorName,
        'color_image_url': r.colorImageUrl,
        'quality_name': r.qualityName,
        'type_name': r.typeName,
        'size_length': r.sizeLength,
        'size_width': r.sizeWidth,
        'product_unit': r.productUnit,
        'edge_code': r.edgeCode,
        'edge_title': r.edgeTitle,
        'available_quantity': r.availableQuantity,
        'order_remaining': r.orderRemaining,
        'order_id': r.orderId,
        'order_date': r.orderDate,
        'client_open_remaining': r.clientOpenRemaining,
        'quantity': r.quantityCtrl.text,
      };

  static ShipmentItemRow _rowFromJson(Map<String, dynamic> json) {
    final row = ShipmentItemRow(
      orderItemId: json['order_item_id'] as int?,
      variantId: json['variant_id'] as int,
      scanned: json['scanned'] as bool? ?? false,
      productName: json['product_name'] as String? ?? '',
      colorName: json['color_name'] as String?,
      colorImageUrl: json['color_image_url'] as String?,
      qualityName: json['quality_name'] as String?,
      typeName: json['type_name'] as String?,
      sizeLength: json['size_length'] as int?,
      sizeWidth: json['size_width'] as int?,
      productUnit: json['product_unit'] as String?,
      edgeCode: json['edge_code'] as String?,
      edgeTitle: json['edge_title'] as String?,
      availableQuantity: json['available_quantity'] as int? ?? 0,
      orderRemaining: json['order_remaining'] as int?,
      orderId: json['order_id'] as int?,
      orderDate: json['order_date'] as String?,
      clientOpenRemaining: json['client_open_remaining'] as int?,
    );

    row.quantityCtrl.text = (json['quantity'] as String?) ?? '';

    // Kept per carpet, not per row: the backend re-attributes one production
    // record per id, so dropping them would leave a scanned carpet counting
    // as ready for whoever it was made for.
    for (final id in (json['scanned_batch_item_ids'] as List<dynamic>?) ?? []) {
      row.addScannedBatchItem(id as int?);
    }
    for (final name in (json['produced_for_clients'] as List<dynamic>?) ?? []) {
      if (name is String) row.producedForClients.add(name);
    }

    return row;
  }

  static Map<String, dynamic> _clientToJson(ClientEntity c) => {
        'id': c.id,
        'uuid': c.uuid,
        'contact_name': c.contactName,
        'phone': c.phone,
        'shop_name': c.shopName,
        'region': c.region,
        'address': c.address,
        'notes': c.notes,
        'created_at': c.createdAt.toIso8601String(),
        'updated_at': c.updatedAt.toIso8601String(),
      };

  static ClientEntity _clientFromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ClientEntity(
      id: json['id'] as int,
      uuid: json['uuid'] as String? ?? '',
      contactName: json['contact_name'] as String?,
      phone: json['phone'] as String?,
      shopName: json['shop_name'] as String? ?? '',
      region: json['region'] as String? ?? '',
      address: json['address'] as String?,
      notes: json['notes'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? now,
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ?? now,
    );
  }
}

/// Everything a restored "add shipment" draft carries.
class ShipmentDraftData {
  final List<ShipmentItemRow> rows;
  final String notes;
  final ClientEntity? client;

  /// Null when the user never picked one — the page falls back to today.
  final DateTime? shipmentDate;

  ShipmentDraftData({
    required this.rows,
    required this.notes,
    this.client,
    this.shipmentDate,
  });
}
