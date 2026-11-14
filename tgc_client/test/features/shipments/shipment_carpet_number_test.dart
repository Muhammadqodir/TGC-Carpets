import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/labeling/domain/carpet_number.dart';
import 'package:tgc_client/features/labeling/domain/product_barcode.dart';
import 'package:tgc_client/features/shipments/domain/entities/shipment_import_entities.dart';
import 'package:tgc_client/features/shipments/domain/repositories/shipment_repository.dart';
import 'package:tgc_client/features/shipments/presentation/widgets/shipment_form_controller.dart';
import 'package:tgc_client/features/shipments/presentation/widgets/shipment_scan_flow.dart';

class _NoRepo implements ShipmentRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('precheck must not reach the server');
}

const _item = ShipmentImportItemEntity(
  orderItemId: 7,
  variantId: 1,
  productName: '6506',
  availableQuantity: 5,
  productionBatchItemId: 11,
);

/// The PDA reads the 21 carpet number; one physical carpet must not go on
/// a shipment twice, and the product barcode beside it names no carpet.
void main() {
  late ShipmentFormController form;
  late ShipmentScanFlow flow;

  setUp(() {
    form = ShipmentFormController();
    flow = ShipmentScanFlow(
      repo: _NoRepo(),
      controller: form,
      clientId: 1,
      clientName: 'MIJOZ',
    );
  });

  test('the same carpet number is refused the second time', () {
    final number = carpetNumber(42);
    expect(flow.precheck(number), isNull);
    flow.apply(_item, number);

    final again = flow.precheck(number);
    expect(again, isNotNull);
    expect(again!.isWarning, isTrue);
    expect(form.items.single.parsedQuantity, 1);
  });

  test('a different carpet of the same product goes onto the same row', () {
    flow.apply(_item, carpetNumber(42));
    expect(flow.precheck(carpetNumber(43)), isNull);
    flow.apply(_item, carpetNumber(43));
    expect(form.items.single.parsedQuantity, 2);
    expect(form.items.single.carpetNumbers, hasLength(2));
  });

  test('old square-code labels are never refused as duplicates', () {
    flow.apply(_item, 'P808 I5648');
    expect(flow.precheck('P808 I5648'), isNull);
    expect(form.items.single.carpetNumbers, isEmpty);
  });

  test('the product barcode says which code to scan instead', () {
    final refused = flow.precheck(productBarcode(42));
    expect(refused, isNotNull);
    expect(refused!.message, contains('21'));
  });

  test('removing the row frees its carpets', () {
    final number = carpetNumber(42);
    flow.apply(_item, number);
    form.removeRow(0);
    expect(flow.precheck(number), isNull);
  });
}
