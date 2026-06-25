import 'package:equatable/equatable.dart';

import '../../domain/entities/shipment_import_entities.dart';

abstract class ShipmentImportEvent extends Equatable {
  const ShipmentImportEvent();

  @override
  List<Object?> get props => [];
}

/// Triggers initial data load: fetches all clients with shippable items.
class ShipmentImportStarted extends ShipmentImportEvent {
  const ShipmentImportStarted();
}

/// User selected a client — loads qualities for that client.
class ShipmentImportClientSelected extends ShipmentImportEvent {
  final ShipmentImportClientEntity client;
  const ShipmentImportClientSelected(this.client);

  @override
  List<Object?> get props => [client];
}

/// User selected a quality — loads shippable items for client + quality.
class ShipmentImportQualitySelected extends ShipmentImportEvent {
  final ShipmentImportQualityEntity quality;
  const ShipmentImportQualitySelected(this.quality);

  @override
  List<Object?> get props => [quality];
}

/// Toggles selection for a single item (by orderItemId).
class ShipmentImportItemToggled extends ShipmentImportEvent {
  final int orderItemId;
  const ShipmentImportItemToggled(this.orderItemId);

  @override
  List<Object?> get props => [orderItemId];
}

/// Selects or deselects all visible items.
class ShipmentImportSelectAllToggled extends ShipmentImportEvent {
  final bool select;
  const ShipmentImportSelectAllToggled(this.select);

  @override
  List<Object?> get props => [select];
}

/// Navigates back one step in the wizard.
class ShipmentImportBackPressed extends ShipmentImportEvent {
  const ShipmentImportBackPressed();
}

/// Confirms the current selection and emits [ShipmentImportDone].
class ShipmentImportConfirmed extends ShipmentImportEvent {
  const ShipmentImportConfirmed();
}
