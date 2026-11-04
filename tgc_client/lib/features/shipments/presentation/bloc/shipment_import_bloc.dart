import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/shipment_import_entities.dart';
import '../../domain/usecases/get_shipment_import_clients_usecase.dart';
import '../../domain/usecases/get_shipment_import_items_usecase.dart';
import 'shipment_import_event.dart';
import 'shipment_import_state.dart';

/// The "pick from the client's orders" list on the shipment form: a client
/// (skipped when the form already has one), then every carpet they still
/// owe, grouped by size, ticked and counted by hand.
///
/// Nothing here looks at the warehouse. The factory does not book carpets
/// into it, and the old wizard's "in stock" filter left most of a client's
/// orders off the list (November 2026).
class ShipmentImportBloc
    extends Bloc<ShipmentImportEvent, ShipmentImportState> {
  final GetShipmentImportClientsUseCase getClientsUseCase;
  final GetShipmentImportItemsUseCase getItemsUseCase;

  /// What the form already holds, from [ShipmentImportStarted].
  Map<int, int> _onForm = const {};

  /// Client list from step 1, once loaded. Null while the picker is locked to
  /// the form's client.
  List<ShipmentImportClientEntity>? _clients;

  ShipmentImportBloc({
    required this.getClientsUseCase,
    required this.getItemsUseCase,
  }) : super(const ShipmentImportInitial()) {
    on<ShipmentImportStarted>(_onStarted);
    on<ShipmentImportClientSelected>(_onClientSelected);
    on<ShipmentImportQualityFilterChanged>(_onQualityFilterChanged);
    on<ShipmentImportSearchChanged>(_onSearchChanged);
    on<ShipmentImportItemToggled>(_onItemToggled);
    on<ShipmentImportItemQuantityChanged>(_onItemQuantityChanged);
    on<ShipmentImportSelectionSet>(_onSelectionSet);
    on<ShipmentImportBackPressed>(_onBackPressed);
    on<ShipmentImportConfirmed>(_onConfirmed);
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> _onStarted(
    ShipmentImportStarted event,
    Emitter<ShipmentImportState> emit,
  ) async {
    _onForm = event.onForm;
    if (event.client != null) {
      await _loadItems(event.client!, emit);
      return;
    }
    await _loadClients(emit);
  }

  Future<void> _loadClients(Emitter<ShipmentImportState> emit) async {
    emit(const ShipmentImportLoading());
    final result = await getClientsUseCase();
    result.fold(
      (f) => emit(ShipmentImportError(
        message: 'Mijozlar yuklanmadi: ${f.message}',
        previousState: const ShipmentImportInitial(),
      )),
      (clients) {
        _clients = clients;
        emit(ShipmentImportClientsLoaded(clients));
      },
    );
  }

  Future<void> _onClientSelected(
    ShipmentImportClientSelected event,
    Emitter<ShipmentImportState> emit,
  ) =>
      _loadItems(event.client, emit);

  Future<void> _loadItems(
    ShipmentImportClientEntity client,
    Emitter<ShipmentImportState> emit,
  ) async {
    final back = _clients != null
        ? ShipmentImportClientsLoaded(_clients!)
        : const ShipmentImportInitial();
    emit(const ShipmentImportLoading());
    // No quality: every open line of the client in one go, filtered here.
    final result = await getItemsUseCase(clientId: client.id);
    result.fold(
      (f) => emit(ShipmentImportError(
        message: 'Buyurtmalar yuklanmadi: ${f.message}',
        previousState: back,
        retryClient: client,
      )),
      (lines) => emit(ShipmentImportItemsLoaded(
        client: client,
        items: ShipmentPickItem.group(lines),
        onForm: _onForm,
        selected: const {},
        allClients: _clients,
      )),
    );
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  void _onQualityFilterChanged(
    ShipmentImportQualityFilterChanged event,
    Emitter<ShipmentImportState> emit,
  ) {
    final s = state;
    if (s is! ShipmentImportItemsLoaded) return;
    emit(s.copyWith(qualityFilter: () => event.qualityName));
  }

  void _onSearchChanged(
    ShipmentImportSearchChanged event,
    Emitter<ShipmentImportState> emit,
  ) {
    final s = state;
    if (s is! ShipmentImportItemsLoaded) return;
    emit(s.copyWith(query: event.query));
  }

  // ── Selection ─────────────────────────────────────────────────────────────

  void _onItemToggled(
    ShipmentImportItemToggled event,
    Emitter<ShipmentImportState> emit,
  ) {
    final s = state;
    if (s is! ShipmentImportItemsLoaded) return;
    final item = _itemOf(s, event.variantId);
    if (item == null) return;

    final updated = Map<int, int>.from(s.selected);
    if (updated.remove(event.variantId) == null) {
      final offered = s.offeredOf(item);
      if (offered <= 0) return; // already all on the form
      updated[event.variantId] = offered;
    }
    emit(s.copyWith(selected: updated));
  }

  void _onItemQuantityChanged(
    ShipmentImportItemQuantityChanged event,
    Emitter<ShipmentImportState> emit,
  ) {
    final s = state;
    if (s is! ShipmentImportItemsLoaded) return;
    final item = _itemOf(s, event.variantId);
    if (item == null) return;

    final offered = s.offeredOf(item);
    if (offered <= 0) return;
    // Capped at what the orders still owe: loading past the order is the
    // form's business, where the row says what happens to the excess.
    final quantity = event.quantity.clamp(1, offered);
    emit(s.copyWith(selected: {...s.selected, event.variantId: quantity}));
  }

  void _onSelectionSet(
    ShipmentImportSelectionSet event,
    Emitter<ShipmentImportState> emit,
  ) {
    final s = state;
    if (s is! ShipmentImportItemsLoaded) return;

    final updated = Map<int, int>.from(s.selected);
    for (final id in event.variantIds) {
      if (!event.select) {
        updated.remove(id);
        continue;
      }
      final item = _itemOf(s, id);
      if (item == null || updated.containsKey(id)) continue;
      final offered = s.offeredOf(item);
      if (offered > 0) updated[id] = offered;
    }
    emit(s.copyWith(selected: updated));
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _onBackPressed(
    ShipmentImportBackPressed event,
    Emitter<ShipmentImportState> emit,
  ) async {
    final s = state;
    if (s is ShipmentImportItemsLoaded) {
      // Opened on the form's client there is no going back: that client's
      // lines are the only ones the form can ship. Changing client is done
      // on the form itself.
      if (s.allClients != null) emit(ShipmentImportClientsLoaded(s.allClients!));
    } else if (s is ShipmentImportError) {
      if (s.retryClient != null) {
        await _loadItems(s.retryClient!, emit);
      } else if (s.previousState is ShipmentImportInitial) {
        await _loadClients(emit);
      } else {
        emit(s.previousState);
      }
    }
  }

  void _onConfirmed(
    ShipmentImportConfirmed event,
    Emitter<ShipmentImportState> emit,
  ) {
    final s = state;
    if (s is! ShipmentImportItemsLoaded || !s.anySelected) return;

    // In list order, so the form fills in the same order the worker ticked
    // through the sizes.
    final selections = <ShipmentPickSelection>[
      for (final item in s.items)
        if (s.selected[item.variantId] case final quantity?)
          (item: item.asImportItem(), quantity: quantity),
    ];

    emit(ShipmentImportDone(selections: selections, client: s.client));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ShipmentPickItem? _itemOf(ShipmentImportItemsLoaded s, int variantId) {
    for (final i in s.items) {
      if (i.variantId == variantId) return i;
    }
    return null;
  }
}
