import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../shipments/domain/entities/shipment_entity.dart';

/// Everything the pricing feature does to a shipment.
///
/// Deliberately narrow: pricing reads one shipment and writes prices onto it.
/// Creating, cancelling and scanning stay in the shipments feature, whose
/// [ShipmentEntity] is shared here rather than duplicated — it is the same
/// document, seen by a different pair of hands.
abstract class ShipmentPricingRepository {
  /// One shipment with its lines, loaded fresh so prices are edited against
  /// what the server holds rather than a row from a list.
  Future<Either<Failure, ShipmentEntity>> getShipment(int id);

  /// Writes prices onto the shipment's lines. The server recomputes what the
  /// client owes and regenerates the hisob-faktura, so the returned shipment
  /// carries fresh document URLs.
  ///
  /// [items] is `{id, price}` per line. Refused with a 403 unless the user is
  /// an admin or a pricing manager.
  Future<Either<Failure, ShipmentEntity>> updatePrices({
    required int id,
    required List<Map<String, dynamic>> items,
  });

  /// What this client last paid for [variantId], for the "last prices"
  /// action. Null when they have never been shipped it.
  Future<Either<Failure, double?>> getLastPrice({
    required int variantId,
    required int clientId,
  });
}
