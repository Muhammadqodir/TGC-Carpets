import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/shipment_entity.dart';
import '../../domain/repositories/shipment_repository.dart';
import '../../domain/usecases/get_shipment_usecase.dart';
import '../../domain/usecases/update_shipment_prices_usecase.dart';

abstract class ShipmentDetailState extends Equatable {
  const ShipmentDetailState();

  @override
  List<Object?> get props => [];
}

class ShipmentDetailLoading extends ShipmentDetailState {
  const ShipmentDetailLoading();
}

class ShipmentDetailLoaded extends ShipmentDetailState {
  final ShipmentEntity shipment;

  /// True while prices are being written. The page keeps showing the
  /// shipment underneath rather than dropping back to a spinner, so the
  /// prices the user just typed stay on screen while they are saved.
  final bool isSaving;

  /// Set once after a successful save, for the confirmation the page shows;
  /// cleared on the next state so it cannot fire twice.
  final bool justSaved;

  const ShipmentDetailLoaded(
    this.shipment, {
    this.isSaving = false,
    this.justSaved = false,
  });

  @override
  List<Object?> get props => [shipment, isSaving, justSaved];
}

class ShipmentDetailError extends ShipmentDetailState {
  final String message;

  const ShipmentDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class ShipmentDetailCubit extends Cubit<ShipmentDetailState> {
  final GetShipmentUseCase _getShipment;
  final UpdateShipmentPricesUseCase _updatePrices;
  final ShipmentRepository _repository;

  ShipmentDetailCubit(
    this._getShipment,
    this._updatePrices,
    this._repository,
  ) : super(const ShipmentDetailLoading());

  Future<void> load(int id) async {
    emit(const ShipmentDetailLoading());
    final result = await _getShipment(id);
    result.fold(
      (failure) => emit(ShipmentDetailError(failure.message)),
      (shipment) => emit(ShipmentDetailLoaded(shipment)),
    );
  }

  /// Saves [prices] (shipment item id → price) and keeps the returned
  /// shipment, whose document URLs point at the newly generated PDFs.
  Future<bool> savePrices(int id, Map<int, double> prices) async {
    final current = state;
    if (current is! ShipmentDetailLoaded) return false;

    emit(ShipmentDetailLoaded(current.shipment, isSaving: true));

    final result = await _updatePrices(
      id: id,
      items: prices.entries
          .map((e) => {'id': e.key, 'price': e.value})
          .toList(),
    );

    return result.fold(
      (failure) {
        emit(ShipmentDetailError(failure.message));
        return false;
      },
      (shipment) {
        emit(ShipmentDetailLoaded(shipment, justSaved: true));
        return true;
      },
    );
  }

  /// The client's last price per variant on this shipment, for the "fill from
  /// last prices" action. Missing variants simply have no last price — the
  /// office types those in.
  Future<Map<int, double>> lastPricesForShipment(ShipmentEntity shipment) async {
    final clientId = shipment.clientId;
    if (clientId == null) return {};

    final variantIds = shipment.items
        .map((i) => i.variantId)
        .whereType<int>()
        .toSet();

    final prices = <int, double>{};
    for (final variantId in variantIds) {
      final result = await _repository.getLastPrice(
        variantId: variantId,
        clientId: clientId,
      );
      result.fold((_) {}, (price) {
        if (price != null) prices[variantId] = price;
      });
    }
    return prices;
  }
}
