import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/labeling/domain/carpet_number.dart';
import 'package:tgc_client/features/shipments/presentation/widgets/shipment_scan_flow.dart';

/// The warning a shipment scan gives for the square code (Data Matrix or QR),
/// which names a production line rather than the carpet.
void main() {
  group('isLineCode', () {
    test('the square code on every label, old and new', () {
      expect(ShipmentScanFlow.isLineCode('P1830 I12876'), isTrue);
      expect(ShipmentScanFlow.isLineCode('PB{835} PBI{5648}'), isTrue);
    });

    test('not the carpet number, a unit serial or a product barcode', () {
      expect(ShipmentScanFlow.isLineCode(carpetNumber(25860)), isFalse);
      expect(ShipmentScanFlow.isLineCode('TGC-U-00036622'), isFalse);
      expect(ShipmentScanFlow.isLineCode('50067572'), isFalse);
    });
  });

  group('confirmLineCode', () {
    Future<bool?> answer(WidgetTester tester, String tap) async {
      bool? result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await ShipmentScanFlow.confirmLineCode(context),
            child: const Text('scan'),
          ),
        ),
      ));
      await tester.tap(find.text('scan'));
      await tester.pumpAndSettle();
      expect(find.text('21 kodni skanerlang'), findsOneWidget);

      await tester.tap(find.textContaining(tap));
      await tester.pumpAndSettle();
      expect(find.text('21 kodni skanerlang'), findsNothing);
      return result;
    }

    testWidgets('the big button adds nothing', (tester) async {
      expect(await answer(tester, 'OK, 21 kodni'), isFalse);
    });

    testWidgets('an old label without a 21 number can still be added',
        (tester) async {
      expect(await answer(tester, 'baribir qo\'shish'), isTrue);
    });
  });
}
