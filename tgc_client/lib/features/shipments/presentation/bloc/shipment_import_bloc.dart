import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/shipment_import_entities.dart';
import '../../domain/usecases/get_shipment_import_clients_usecase.dart';
import '../../domain/usecases/get_shipment_import_items_usecase.dart';
import '../../domain/usecases/get_shipment_import_qualities_usecase.dart';
import 'shipment_import_event.dart';
import 'shipment_import_state.dart';

class ShipmentImportBloc
    extends Bloc<ShipmentImportEvent, ShipmentImportState> {
  final GetShipmentImportClientsUseCase getClientsUseCase;
  final GetShipmentImportQualitiesUseCase getQualitiesUseCase;
  final GetShipmentImportItemsUseCase getItemsUseCase;

  ShipmentImportBloc({
    required this.getClientsUseCase,
    required this.getQualitiesUseCase,
    required this.getItemsUseCase,
  }) : super(const ShipmentImportInitial()) {
    on<ShipmentImportStarted>(_onStarted);
    on<ShipmentImportClientSelected>(_onClientSelected);
    on<ShipmentImportQualitySelected>(_onQualitySelected);
    on<ShipmentImportItemToggled>(_onItemToggled);
    on<ShipmentImportSelectAllToggled>(_onSelectAllToggled);
    on<ShipmentImportBackPressed>(_onBackPressed);
    on<ShipmentImportConfirmed>(_onConfirmed);
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _onStarted(
    ShipmentImportStarted event,
    Emitter<ShipmentImportState> emit,
  ) async {
    emit(const ShipmentImportLoading());
    final result = await getClientsUseCase();
    result.fold(
      (f) => emit(ShipmentImportError(
        message: 'Mijozlar yuklanmadi: ${f.message}',
        previousState: const ShipmentImportInitial(),
      )),
      (clients) => emit(ShipmentImportClientsLoaded(clients)),
    );
  }

  Future<void> _onClientSelected(
    ShipmentImportClientSelected event,
    Emitter<ShipmentImportState> emit,
  ) async {
    final allClients = _allClients();
    emit(const ShipmentImportLoading());
    final result = await getQualitiesUseCase(clientId: event.client.id);
    result.fold(
      (f) => emit(ShipmentImportError(
        message: 'Sifatlar yuklanmadi: ${f.message}',
        previousState: ShipmentImportClientsLoaded(allClients),
      )),
      (qualities) => emit(ShipmentImportQualitiesLoaded(
        client: event.client,
        qualities: qualities,
        allClients: allClients,
      )),
    );
  }

  Future<void> _onQualitySelected(
    ShipmentImportQualitySelected event,
    Emitter<ShipmentImportState> emit,
  ) async {
    final s = state;
    if (s is! ShipmentImportQualitiesLoaded) return;

    emit(const ShipmentImportLoading());
    final result = await getItemsUseCase(
      clientId: s.client.id,
      qualityName: event.quality.qualityName,
    );
    result.fold(
      (f) => emit(ShipmentImportError(
        message: 'Mahsulotlar yuklanmadi: ${f.message}',
        previousState: s,
      )),
      (items) => emit(ShipmentImportItemsLoaded(
        client: s.client,
        quality: event.quality,
        items: items,
        selectedIds: const {},
        allQualities: s.qualities,
        allClients: s.allClients,
      )),
    );
  }

  void _onItemToggled(
    ShipmentImportItemToggled event,
    Emitter<ShipmentImportState> emit,
  ) {
    final s = state;
    if (s is! ShipmentImportItemsLoaded) return;

    final updated = Set<int>.from(s.selectedIds);
    if (updated.contains(event.orderItemId)) {
      updated.remove(event.orderItemId);
    } else {
      updated.add(event.orderItemId);
    }
    emit(s.copyWith(selectedIds: updated));
  }

  void _onSelectAllToggled(
    ShipmentImportSelectAllToggled event,
    Emitter<ShipmentImportState> emit,
  ) {
    final s = state;
    if (s is! ShipmentImportItemsLoaded) return;

    final updated = event.select
        ? s.items.map((i) => i.orderItemId).toSet()
        : <int>{};
    emit(s.copyWith(selectedIds: updated));
  }

  void _onBackPressed(
    ShipmentImportBackPressed event,
    Emitter<ShipmentImportState> emit,
  ) {
    final s = state;
    if (s is ShipmentImportItemsLoaded) {
      emit(ShipmentImportQualitiesLoaded(
        client: s.client,
        qualities: s.allQualities,
        allClients: s.allClients,
      ));
    } else if (s is ShipmentImportQualitiesLoaded) {
      emit(ShipmentImportClientsLoaded(s.allClients));
    } else if (s is ShipmentImportError) {
      emit(s.previousState);
    }
  }

  void _onConfirmed(
    ShipmentImportConfirmed event,
    Emitter<ShipmentImportState> emit,
  ) {
    final s = state;
    if (s is! ShipmentImportItemsLoaded || s.selectedIds.isEmpty) return;

    final selected = s.items
        .where((i) => s.selectedIds.contains(i.orderItemId))
        .toList();

    emit(ShipmentImportDone(selectedItems: selected, client: s.client));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<ShipmentImportClientEntity> _allClients() {
    final s = state;
    if (s is ShipmentImportClientsLoaded) return s.clients;
    if (s is ShipmentImportQualitiesLoaded) return s.allClients;
    if (s is ShipmentImportItemsLoaded) return s.allClients;
    return [];
  }
}
