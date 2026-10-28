import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/shipments/domain/entities/shipment_import_entities.dart';
import 'package:tgc_client/features/shipments/presentation/widgets/shipment_form_controller.dart';
import 'package:tgc_client/features/shipments/presentation/widgets/shipment_item_row.dart';

ShipmentImportItemEntity _item({
  int? orderItemId = 7,
  int available = 2,
  int? orderRemaining,
  int? clientOpen,
  String? producedFor,
}) =>
    ShipmentImportItemEntity(
      orderItemId: orderItemId,
      variantId: 1,
      productName: '6506',
      availableQuantity: available,
      orderRemaining: orderRemaining,
      clientOpenRemaining: clientOpen,
      producedForClient: producedFor,
      productionBatchItemId: 11,
    );

void main() {
  test('a quantity typed past the order counts as beyond it', () {
    final row = ShipmentItemRow.fromImportItem(_item(orderRemaining: 2), initialQuantity: 5);
    expect(row.beyondOrder, 3);
    expect(row.isOffOrder, isFalse);
  });

  test('stock-capped wizard rows measure against the order, not the stock', () {
    final row = ShipmentItemRow.fromImportItem(
        _item(available: 2, orderRemaining: 5), initialQuantity: 4);
    expect(row.beyondOrder, 0);
  });

  test('past one order but within the client total is not beyond', () {
    final row = ShipmentItemRow.fromImportItem(
        _item(orderRemaining: 10, clientOpen: 44), initialQuantity: 11);
    expect(row.beyondOrder, 0);
  });

  test('an off-order row is flagged as such and never as beyond', () {
    final row = ShipmentItemRow.fromImportItem(_item(orderItemId: null, available: 0), initialQuantity: 3);
    expect(row.isOffOrder, isTrue);
    expect(row.beyondOrder, 0);
    expect(row.pieces.single.orderItemId, isNull);
  });

  test('scanning another client\'s carpet keeps their name on the row', () {
    final form = ShipmentFormController();
    form.addOrIncrementItem(_item(orderItemId: null, available: 0, producedFor: 'AKRAM AKA'));
    form.addOrIncrementItem(_item(orderItemId: null, available: 0, producedFor: 'ABDUBANNO AKA'));
    expect(form.items.single.parsedQuantity, 2);
    expect(form.items.single.producedForClients, {'AKRAM AKA', 'ABDUBANNO AKA'});
    form.dispose();
  });

  test('a stock import of one product on two lines is one row', () {
    final form = ShipmentFormController()
      ..importFromStock([
        _item(orderItemId: 1, available: 2, orderRemaining: 2),
        _item(orderItemId: 2, available: 3, orderRemaining: 3),
      ]);
    expect(form.items.single.parsedQuantity, 5);
    expect(form.items.single.pieces.map((p) => (p.orderItemId, p.quantity)), [(1, 2), (2, 3)]);
    form.dispose();
  });
}
