import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/print_history_entity.dart';
import '../../domain/entities/labeling_item_entity.dart';

class PrintHistoryService {
  static const String _key = 'print_history';
  static const int _maxHistoryItems = 100;

  final SharedPreferences _prefs;

  PrintHistoryService(this._prefs);

  /// Get all print history items, sorted by most recent first
  Future<List<PrintHistoryEntity>> getHistory() async {
    final jsonString = _prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      final items = jsonList
          .map((json) => PrintHistoryEntity.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by printedAt descending (most recent first)
      items.sort((a, b) => b.printedAt.compareTo(a.printedAt));
      return items;
    } catch (e) {
      return [];
    }
  }

  /// Add a new print history item from a labeling item.
  ///
  /// With [carpetNumber], every label keeps its own entry, so a reprint repeats
  /// the number of the carpet it replaces and not that of the newest carpet of
  /// the same product. Entries without one, saved before labels had numbers,
  /// stay one per product and give way to the first new label of that product.
  Future<void> addToHistory(LabelingItemEntity item, {String? carpetNumber}) async {
    final history = await getHistory();

    final newItem = PrintHistoryEntity(
      variantId: item.variantId,
      productName: item.productName,
      colorName: item.colorName,
      colorImageUrl: item.colorImageUrl,
      sizeLength: item.sizeLength,
      sizeWidth: item.sizeWidth,
      qualityName: item.qualityName,
      productTypeName: item.productTypeName,
      variantBarcode: item.variantBarcode,
      batchId: item.batchId,
      batchTitle: item.batchTitle,
      printedAt: DateTime.now().millisecondsSinceEpoch,
      itemId: item.id,
      clientId: item.clientId ?? 0,
      carpetNumber: carpetNumber,
      actualLengthCm: item.actualLengthCm,
    );

    history.removeWhere((h) => h.variantId == item.variantId && h.carpetNumber == null);

    // Add new item at the beginning
    history.insert(0, newItem);

    // Keep only the most recent items
    if (history.length > _maxHistoryItems) {
      history.removeRange(_maxHistoryItems, history.length);
    }

    await _saveHistory(history);
  }

  /// Clear all print history
  Future<void> clearHistory() async {
    await _prefs.remove(_key);
  }

  Future<void> _saveHistory(List<PrintHistoryEntity> history) async {
    final jsonList = history.map((item) => item.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await _prefs.setString(_key, jsonString);
  }
}
