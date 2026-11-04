import 'package:equatable/equatable.dart';

import '../../domain/entities/shipment_import_entities.dart';

abstract class ShipmentImportState extends Equatable {
  const ShipmentImportState();

  @override
  List<Object?> get props => [];
}

class ShipmentImportInitial extends ShipmentImportState {
  const ShipmentImportInitial();
}

class ShipmentImportLoading extends ShipmentImportState {
  const ShipmentImportLoading();
}

/// Step 1: clients with open orders.
class ShipmentImportClientsLoaded extends ShipmentImportState {
  final List<ShipmentImportClientEntity> clients;
  const ShipmentImportClientsLoaded(this.clients);

  @override
  List<Object?> get props => [clients];
}

/// One size on the list: its label ("200×300", or null for carpets with no
/// size) and the carpets of that size.
typedef ShipmentPickGroup = ({String? sizeLabel, List<ShipmentPickItem> items});

/// Step 2: every open order line of [client], one row per carpet, with what
/// is ticked and how many of each.
class ShipmentImportItemsLoaded extends ShipmentImportState {
  final ShipmentImportClientEntity client;
  final List<ShipmentPickItem> items;

  /// How many of each carpet the shipment form already holds, by variant id.
  final Map<int, int> onForm;

  /// Ticked carpets and the quantity chosen for each, by variant id.
  final Map<int, int> selected;

  /// The one quality shown, or null for all.
  final String? qualityFilter;
  final String query;

  /// Kept for going back to step 1. Null when the picker opened on the
  /// form's client, which has no step 1 to go back to.
  final List<ShipmentImportClientEntity>? allClients;

  const ShipmentImportItemsLoaded({
    required this.client,
    required this.items,
    required this.onForm,
    required this.selected,
    this.qualityFilter,
    this.query = '',
    this.allClients,
  });

  /// What is still left to load of [item]: what its orders owe, less what
  /// the form already holds.
  int offeredOf(ShipmentPickItem item) {
    final left = item.remaining - (onForm[item.variantId] ?? 0);
    return left > 0 ? left : 0;
  }

  /// Every quality on the client's orders, with how many carpets of each.
  List<ShipmentImportQualityEntity> get qualities {
    final counts = <String, int>{};
    for (final i in items) {
      final q = i.first.qualityName ?? '—';
      counts[q] = (counts[q] ?? 0) + 1;
    }
    final names = counts.keys.toList()..sort();
    return [
      for (final n in names)
        ShipmentImportQualityEntity(qualityName: n, itemCount: counts[n]!),
    ];
  }

  /// The carpets the quality filter and search let through.
  List<ShipmentPickItem> get visibleItems {
    final q = query.trim().toLowerCase();
    return items.where((i) {
      if (qualityFilter != null && (i.first.qualityName ?? '—') != qualityFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      final f = i.first;
      return [f.productName, f.colorName, f.sizeLabel, f.edgeCode, f.typeName]
          .whereType<String>()
          .any((s) => s.toLowerCase().contains(q));
    }).toList();
  }

  /// [visibleItems] by size, smallest first (the server sends them sorted),
  /// carpets with no size last.
  List<ShipmentPickGroup> get groups {
    final bySize = <String?, List<ShipmentPickItem>>{};
    for (final i in visibleItems) {
      bySize.putIfAbsent(i.first.sizeLabel, () => []).add(i);
    }
    final labels = bySize.keys.toList();
    if (labels.remove(null)) labels.add(null);
    return [for (final l in labels) (sizeLabel: l, items: bySize[l]!)];
  }

  bool isSelectable(ShipmentPickItem item) => offeredOf(item) > 0;

  int get selectedCount => selected.length;
  int get selectedQuantity => selected.values.fold(0, (s, q) => s + q);
  bool get anySelected => selected.isNotEmpty;

  /// True when every carpet of [ofItems] that can be ticked is ticked.
  bool allSelected(List<ShipmentPickItem> ofItems) {
    final selectable = ofItems.where(isSelectable);
    return selectable.isNotEmpty &&
        selectable.every((i) => selected.containsKey(i.variantId));
  }

  ShipmentImportItemsLoaded copyWith({
    Map<int, int>? selected,
    String? Function()? qualityFilter,
    String? query,
  }) {
    return ShipmentImportItemsLoaded(
      client: client,
      items: items,
      onForm: onForm,
      selected: selected ?? this.selected,
      qualityFilter: qualityFilter != null ? qualityFilter() : this.qualityFilter,
      query: query ?? this.query,
      allClients: allClients,
    );
  }

  @override
  List<Object?> get props =>
      [client, items, onForm, selected, qualityFilter, query, allClients];
}

/// An error occurred; [previousState] is available for retry.
class ShipmentImportError extends ShipmentImportState {
  final String message;
  final ShipmentImportState previousState;

  /// The client whose list failed to load, so "retry" can load it again.
  final ShipmentImportClientEntity? retryClient;

  const ShipmentImportError({
    required this.message,
    required this.previousState,
    this.retryClient,
  });

  @override
  List<Object?> get props => [message, previousState, retryClient];
}

/// Emitted after [ShipmentImportConfirmed]; the page pops and uses this.
class ShipmentImportDone extends ShipmentImportState {
  final List<ShipmentPickSelection> selections;
  final ShipmentImportClientEntity client;

  const ShipmentImportDone({
    required this.selections,
    required this.client,
  });

  @override
  List<Object?> get props => [selections, client];
}
