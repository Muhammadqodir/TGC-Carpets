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

/// Step 1: clients loaded and displayed.
class ShipmentImportClientsLoaded extends ShipmentImportState {
  final List<ShipmentImportClientEntity> clients;
  const ShipmentImportClientsLoaded(this.clients);

  @override
  List<Object?> get props => [clients];
}

/// Step 2: qualities loaded for [client].
class ShipmentImportQualitiesLoaded extends ShipmentImportState {
  final ShipmentImportClientEntity client;
  final List<ShipmentImportQualityEntity> qualities;
  /// Kept for back-navigation to step 1.
  final List<ShipmentImportClientEntity> allClients;

  const ShipmentImportQualitiesLoaded({
    required this.client,
    required this.qualities,
    required this.allClients,
  });

  @override
  List<Object?> get props => [client, qualities, allClients];
}

/// Step 3: items loaded for [client] + [quality], with mutable selection.
class ShipmentImportItemsLoaded extends ShipmentImportState {
  final ShipmentImportClientEntity client;
  final ShipmentImportQualityEntity quality;
  final List<ShipmentImportItemEntity> items;
  final Set<int> selectedIds;
  /// Kept for back-navigation to step 2.
  final List<ShipmentImportQualityEntity> allQualities;
  /// Kept for back-navigation to step 1.
  final List<ShipmentImportClientEntity> allClients;

  const ShipmentImportItemsLoaded({
    required this.client,
    required this.quality,
    required this.items,
    required this.selectedIds,
    required this.allQualities,
    required this.allClients,
  });

  bool get allSelected =>
      items.isNotEmpty &&
      items.every((i) => selectedIds.contains(i.orderItemId));

  bool get anySelected => items.any((i) => selectedIds.contains(i.orderItemId));

  ShipmentImportItemsLoaded copyWith({Set<int>? selectedIds}) {
    return ShipmentImportItemsLoaded(
      client: client,
      quality: quality,
      items: items,
      selectedIds: selectedIds ?? this.selectedIds,
      allQualities: allQualities,
      allClients: allClients,
    );
  }

  @override
  List<Object?> get props =>
      [client, quality, items, selectedIds, allQualities, allClients];
}

/// An error occurred; [previousState] is available for retry.
class ShipmentImportError extends ShipmentImportState {
  final String message;
  final ShipmentImportState previousState;

  const ShipmentImportError({
    required this.message,
    required this.previousState,
  });

  @override
  List<Object?> get props => [message, previousState];
}

/// Emitted after [ShipmentImportConfirmed]; the page pops and uses this.
class ShipmentImportDone extends ShipmentImportState {
  final List<ShipmentImportItemEntity> selectedItems;
  final ShipmentImportClientEntity client;

  const ShipmentImportDone({
    required this.selectedItems,
    required this.client,
  });

  @override
  List<Object?> get props => [selectedItems, client];
}
