import 'package:equatable/equatable.dart';

import '../../domain/entities/shipment_import_entities.dart';

abstract class ShipmentImportEvent extends Equatable {
  const ShipmentImportEvent();

  @override
  List<Object?> get props => [];
}

/// Opens the picker. With [client] (the one already on the shipment form) it
/// goes straight to that client's order list; without, it lists the clients
/// with open orders first.
///
/// [onForm] is how many of each carpet the form already holds, by variant id,
/// so the list offers only what is still left to load.
class ShipmentImportStarted extends ShipmentImportEvent {
  final ShipmentImportClientEntity? client;
  final Map<int, int> onForm;

  const ShipmentImportStarted({this.client, this.onForm = const {}});

  @override
  List<Object?> get props => [client, onForm];
}

/// User picked a client — loads every open order line of theirs.
class ShipmentImportClientSelected extends ShipmentImportEvent {
  final ShipmentImportClientEntity client;
  const ShipmentImportClientSelected(this.client);

  @override
  List<Object?> get props => [client];
}

/// Shows one quality only, or every quality when [qualityName] is null.
class ShipmentImportQualityFilterChanged extends ShipmentImportEvent {
  final String? qualityName;
  const ShipmentImportQualityFilterChanged(this.qualityName);

  @override
  List<Object?> get props => [qualityName];
}

/// Narrows the list to carpets whose name or colour contains [query].
class ShipmentImportSearchChanged extends ShipmentImportEvent {
  final String query;
  const ShipmentImportSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

/// Ticks or unticks one carpet (by variant id). Ticking starts it at all
/// that is still left to load.
class ShipmentImportItemToggled extends ShipmentImportEvent {
  final int variantId;
  const ShipmentImportItemToggled(this.variantId);

  @override
  List<Object?> get props => [variantId];
}

/// The quantity typed or stepped for a ticked carpet.
class ShipmentImportItemQuantityChanged extends ShipmentImportEvent {
  final int variantId;
  final int quantity;
  const ShipmentImportItemQuantityChanged(this.variantId, this.quantity);

  @override
  List<Object?> get props => [variantId, quantity];
}

/// Ticks or unticks several carpets at once — everything shown, or one size.
class ShipmentImportSelectionSet extends ShipmentImportEvent {
  final List<int> variantIds;
  final bool select;
  const ShipmentImportSelectionSet(this.variantIds, {required this.select});

  @override
  List<Object?> get props => [variantIds, select];
}

/// Navigates back one step in the wizard.
class ShipmentImportBackPressed extends ShipmentImportEvent {
  const ShipmentImportBackPressed();
}

/// Confirms the current selection and emits [ShipmentImportDone].
class ShipmentImportConfirmed extends ShipmentImportEvent {
  const ShipmentImportConfirmed();
}
