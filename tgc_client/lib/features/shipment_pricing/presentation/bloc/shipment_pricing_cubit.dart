import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shipments/domain/entities/shipment_entity.dart';
import '../../domain/repositories/shipment_pricing_repository.dart';
import '../../domain/usecases/get_shipment_for_pricing_usecase.dart';
import '../../domain/usecases/update_shipment_prices_usecase.dart';

abstract class ShipmentPricingState extends Equatable {
  const ShipmentPricingState();

  @override
  List<Object?> get props => [];
}

class ShipmentPricingLoading extends ShipmentPricingState {
  const ShipmentPricingLoading();
}

class ShipmentPricingLoaded extends ShipmentPricingState {
  final ShipmentEntity shipment;

  /// True while prices are being written. The page keeps showing the
  /// shipment underneath rather than dropping back to a spinner, so the
  /// prices the user just typed stay on screen while they are saved.
  final bool isSaving;

  /// Set once after a successful save, for the confirmation the page shows;
  /// cleared on the next state so it cannot fire twice.
  final bool justSaved;

  const ShipmentPricingLoaded(
    this.shipment, {
    this.isSaving = false,
    this.justSaved = false,
  });

  @override
  List<Object?> get props => [shipment, isSaving, justSaved];
}

class ShipmentPricingError extends ShipmentPricingState {
  final String message;

  const ShipmentPricingError(this.message);

  @override
  List<Object?> get props => [message];
}

class ShipmentPricingCubit extends Cubit<ShipmentPricingState> {
  final GetShipmentForPricingUseCase _getShipment;
  final UpdateShipmentPricesUseCase _updatePrices;
  final ShipmentPricingRepository _repository;

  ShipmentPricingCubit(
    this._getShipment,
    this._updatePrices,
    this._repository,
  ) : super(const ShipmentPricingLoading());

  Future<void> load(int id) async {
    emit(const ShipmentPricingLoading());
    final result = await _getShipment(id);
    result.fold(
      (failure) => emit(ShipmentPricingError(failure.message)),
      (shipment) => emit(ShipmentPricingLoaded(shipment)),
    );
  }

  /// Saves [prices] (shipment item id → price) and keeps the returned
  /// shipment, whose document URLs point at the newly generated PDFs.
  Future<bool> savePrices(int id, Map<int, double> prices) async {
    final current = state;
    if (current is! ShipmentPricingLoaded) return false;

    emit(ShipmentPricingLoaded(current.shipment, isSaving: true));

    final result = await _updatePrices(
      id: id,
      items: prices.entries
          .map((e) => {'id': e.key, 'price': e.value})
          .toList(),
    );

    return result.fold(
      (failure) {
        emit(ShipmentPricingError(failure.message));
        return false;
      },
      (shipment) {
        emit(ShipmentPricingLoaded(shipment, justSaved: true));
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
