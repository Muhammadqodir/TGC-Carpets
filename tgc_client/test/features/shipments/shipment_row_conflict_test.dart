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
    expect(row.beyondLine, 3);
    expect(row.isOffOrder, isFalse);
  });

  test('stock-capped wizard rows measure against the order, not the stock', () {
    // Order owes 5, stock only had 2: typing 4 is a stock question, not beyond the order.
    final row = ShipmentItemRow.fromImportItem(
        _item(available: 2, orderRemaining: 5), initialQuantity: 4);
    expect(row.beyondLine, 0);
  });

  test('an off-order row is flagged as such and never as beyond', () {
    final row = ShipmentItemRow.fromImportItem(_item(orderItemId: null, available: 0), initialQuantity: 3);
    expect(row.isOffOrder, isTrue);
    expect(row.beyondLine, 0);
  });

  test('scanning another client\'s carpet keeps their name on the row', () {
    final form = ShipmentFormController();
    form.addOrIncrementItem(_item(orderItemId: null, available: 0, producedFor: 'AKRAM AKA'));
    form.addOrIncrementItem(_item(orderItemId: null, available: 0, producedFor: 'ABDUBANNO AKA'));
    expect(form.items.single.parsedQuantity, 2);
    expect(form.items.single.producedForClients, {'AKRAM AKA', 'ABDUBANNO AKA'});
    form.dispose();
  });

  test('three orders of one carpet, each +1: past each order, not past the client', () {
    // ABDUBANNO AKA, 2026-10-28: six open orders for 1447 350x400, 44 owed.
    final form = ShipmentFormController();
    for (final (id, owed, loaded) in [(18078, 10, 11), (2263, 6, 7), (7009, 6, 7)]) {
      form.addOrIncrementItem(_item(orderItemId: id, available: owed, orderRemaining: owed, clientOpen: 44));
      form.items.last.quantityCtrl.text = '$loaded';
    }

    expect(form.items.map((r) => r.beyondLine), [1, 1, 1]);
    expect(form.beyondClientOrders(1), 0, reason: 'the client still owes 44');
    expect(form.totalBeyondClientOrders, 0);
    expect(form.isLastOnOrderRowOf(form.items.last), isTrue);
    expect(form.isLastOnOrderRowOf(form.items.first), isFalse);
    form.dispose();
  });

  test('past everything the client owes is beyond the order', () {
    final form = ShipmentFormController();
    form.addOrIncrementItem(_item(orderItemId: 1, available: 2, orderRemaining: 2, clientOpen: 3));
    form.items.single.quantityCtrl.text = '5';
    expect(form.beyondClientOrders(1), 2);
    form.dispose();
  });

  test('wizard rows without the client total measure against the lines on the form', () {
    final form = ShipmentFormController();
    form.addOrIncrementItem(_item(orderItemId: 1, available: 2, orderRemaining: 2));
    form.addOrIncrementItem(_item(orderItemId: 2, available: 3, orderRemaining: 3));
    form.items[0].quantityCtrl.text = '4';
    form.items[1].quantityCtrl.text = '3';
    expect(form.beyondClientOrders(1), 2);
    form.dispose();
  });
}
