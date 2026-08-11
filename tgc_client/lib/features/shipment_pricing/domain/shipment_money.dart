import '../../shipments/domain/entities/shipment_entity.dart';
import '../../shipments/domain/entities/shipment_item_entity.dart';

/// What a saved shipment is worth.
///
/// Extensions rather than getters on the entities themselves: a shipment is a
/// warehouse document that happens to carry prices, and only this feature
/// turns those prices into money. Keeping the arithmetic here means the
/// shipments feature can be read end to end without meeting a currency.
///
/// These read what the server has stored. The pricing page computes its own
/// totals from the fields being typed, which is a different number until the
/// save lands.
extension ShipmentItemMoney on ShipmentItemEntity {
  /// Unit-aware, matching ShipmentItem::lineTotal() on the server:
  ///  - piece: price × quantity
  ///  - m²:    price × area
  double get lineTotal =>
      productUnit == 'piece' ? price * quantity : price * squareMeters;
}

extension ShipmentMoney on ShipmentEntity {
  /// Grand total in USD. 0 means nobody has priced it yet — shipments leave
  /// the warehouse unpriced.
  double get grandTotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);
}
