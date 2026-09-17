import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/labeling/data/models/labeling_item_model.dart';
import 'package:tgc_client/features/labeling/domain/entities/print_history_entity.dart';
import 'package:tgc_client/features/labeling/domain/label_print_code.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/labels/print_label_70_50.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/labels/print_label_70_50_arab.dart';

/// The small "S_123_04_14 15.59" code on the right edge of every label:
/// shift, client id, month_day and hour.minute of printing.
void main() {
  group('buildLabelPrintCode', () {
    test('matches the agreed example', () {
      expect(
        buildLabelPrintCode(
            shift: 'S', clientId: 123, printedAt: DateTime(2026, 4, 14, 15, 59)),
        'S_123_04_14 15.59',
      );
    });

    test('pads month, day, hour and minute to two digits', () {
      expect(
        buildLabelPrintCode(
            shift: 'I', clientId: 7, printedAt: DateTime(2026, 1, 5, 9, 3)),
        'I_7_01_05 09.03',
      );
    });

    test('a carpet made for stock has client 0', () {
      expect(
        buildLabelPrintCode(
            shift: 'I', clientId: null, printedAt: DateTime(2026, 12, 31, 23, 0)),
        'I_0_12_31 23.00',
      );
    });
  });

  group('labelShiftLetter', () {
    test('1st shift account prints I, 2nd shift account prints S', () {
      expect(labelShiftLetter('yorliq1@tgc-carpets.uz'), 'I');
      expect(labelShiftLetter('yorliq2@tgc-carpets.uz'), 'S');
      expect(labelShiftLetter(' Yorliq2@TGC-carpets.uz '), 'S');
    });

    test('anyone else prints X, never a shift letter', () {
      expect(labelShiftLetter('admin@tgc-carpets.uz'), 'X');
      expect(labelShiftLetter('ilhomjon@tgc-carpets.uz'), 'X');
      expect(labelShiftLetter(null), 'X');
    });
  });

  group('client id reaches the label', () {
    test('labeling item reads client_id from the API', () {
      final item = LabelingItemModel.fromJson({
        'id': 9121,
        'production_batch_id': 1323,
        'client_id': 123,
        'client_name': 'A MIJOZ',
        'planned_quantity': 2,
      });
      expect(item.clientId, 123);
      expect(item.copyWith(producedQuantity: 1).clientId, 123);
    });

    test('print history keeps the client id, stock as 0', () {
      const entry = PrintHistoryEntity(
        variantId: 5984,
        productName: '1568',
        batchId: 1323,
        printedAt: 0,
        itemId: 9121,
        clientId: 0,
      );
      expect(PrintHistoryEntity.fromJson(entry.toJson()).clientId, 0);
    });

    test('history saved before the print code has no client id', () {
      final legacy = PrintHistoryEntity.fromJson({
        'variantId': 5984,
        'productName': '1568',
        'batchId': 1323,
        'printedAt': 0,
        'itemId': 9121,
      });
      expect(legacy.clientId, isNull);
    });
  });

  group('label templates', () {
    final labels = <String, Widget Function(String?)>{
      'PrintLabel7050': (code) => PrintLabel7050(
            barcodeValue: '2984200059847',
            qrData: 'P1 I1',
            productName: '1568',
            printCode: code,
          ),
      'PrintLabel7050Arab': (code) => PrintLabel7050Arab(
            barcodeValue: '2984200059847',
            qrData: 'P1 I1',
            productName: '1568',
            printCode: code,
          ),
    };

    labels.forEach((name, build) {
      testWidgets('$name prints the code vertically', (tester) async {
        await tester.pumpWidget(MaterialApp(home: build('S_123_04_14 15.59')));

        expect(tester.takeException(), isNull);
        final code = find.text('S_123_04_14 15.59');
        expect(code, findsOneWidget);
        expect(
          find.ancestor(of: code, matching: find.byType(RotatedBox)),
          findsOneWidget,
        );
      });

      testWidgets('$name leaves it off without a code', (tester) async {
        await tester.pumpWidget(MaterialApp(home: build(null)));

        expect(tester.takeException(), isNull);
        expect(find.textContaining('_'), findsNothing);
      });
    });

    testWidgets('the Arabic template no longer prints "صحيح"', (tester) async {
      await tester.pumpWidget(MaterialApp(home: labels['PrintLabel7050Arab']!('I_0_01_01 00.00')));

      expect(find.text('صحيح'), findsNothing);
    });
  });
}
