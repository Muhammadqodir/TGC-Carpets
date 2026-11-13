import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/labeling/domain/product_barcode.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/labels/print_label_70_50.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/labels/print_label_70_50_arab.dart';

/// The label's product barcode is digits only, the same number the backend
/// stores (ProductBarcodeTest in tgc_backend uses the same table), and never
/// falls back to the "TGC-" text some clients' systems reject.
void main() {
  group('productBarcode', () {
    const sameAsBackend = {
      1: '2984200000016',
      42: '2984200000429',
      5984: '2984200059847',
      9999999: '2984299999994',
    };

    sameAsBackend.forEach((id, expected) {
      test('variant $id → $expected', () {
        expect(productBarcode(id), expected);
        expect(isEan13(productBarcode(id)), isTrue);
      });
    });

    test('ids that do not fit are refused rather than truncated', () {
      expect(() => productBarcode(0), throwsArgumentError);
      expect(() => productBarcode(10000000), throwsArgumentError);
    });
  });

  group('isEan13', () {
    test('accepts a real retail EAN-13 and ours', () {
      expect(isEan13('4006381333931'), isTrue);
      expect(isEan13('2984200059847'), isTrue);
    });

    test('rejects a wrong check digit, letters and wrong lengths', () {
      expect(isEan13('2984200059846'), isFalse);
      expect(isEan13('TGC-00005984'), isFalse);
      expect(isEan13('298420005984'), isFalse);
      expect(isEan13('29842000598470'), isFalse);
      expect(isEan13(''), isFalse);
    });
  });

  group('labelBarcodeValue', () {
    test('prints the server value when it is already digits', () {
      expect(labelBarcodeValue(stored: '2984200059847', variantId: 5984),
          '2984200059847');
    });

    test('print history saved before the switch reprints without TGC-', () {
      expect(labelBarcodeValue(stored: 'TGC-00005984', variantId: 5984),
          '2984200059847');
      expect(labelBarcodeValue(stored: 'TGC-VAR-00005984', variantId: 5984),
          '2984200059847');
    });

    test('no stored value falls back to the derived one', () {
      expect(labelBarcodeValue(stored: null, variantId: 42), '2984200000429');
      expect(labelBarcodeValue(stored: '', variantId: 42), '2984200000429');
    });
  });

  group('label widgets', () {
    final labels = <String, Widget Function(String)>{
      'PrintLabel7050': (value) => PrintLabel7050(
            barcodeValue: value,
            qrData: 'P1 I1',
            productName: '1568',
            quality: 'Ronaldo',
            color: 'Beige',
            sizeLabel: '200x300',
            edgeCode: 'R',
          ),
      'PrintLabel7050Arab': (value) => PrintLabel7050Arab(
            barcodeValue: value,
            qrData: 'P1 I1',
            productName: '1568',
            quality: 'Ronaldo',
            color: 'Beige',
            sizeLabel: '200x300',
            edgeCode: 'R',
          ),
    };

    labels.forEach((name, build) {
      testWidgets('$name draws the product barcode as a plain Code 128',
          (tester) async {
        await tester.pumpWidget(MaterialApp(home: build('2984200059847')));

        expect(tester.takeException(), isNull);
        final product = productBarcodeOn(tester);
        expect(product.barcode.name, 'CODE 128');
        expect(String.fromCharCodes(product.data), '2984200059847');
      });

      testWidgets('$name draws the scan code as a Data Matrix', (tester) async {
        await tester.pumpWidget(MaterialApp(home: build('2984200059847')));

        final scanCode = tester
            .widgetList<BarcodeWidget>(find.byType(BarcodeWidget))
            .singleWhere((w) => w.barcode.name == scanCodeName);
        expect(String.fromCharCodes(scanCode.data), 'P1 I1');
      });

      testWidgets('$name draws a long value without overflowing',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: PrintLabel7050(
            barcodeValue: '2984200059847',
            carpetBarcode: '210000012345',
            qrData: 'P12345 I123456',
            quality: 'ASL PODSHOX GILAMI ASL PODSHOX GILAMI',
            productName: 'A VERY LONG DESIGN NAME INDEED',
            sizeLabel: '400×1000',
            edgeCode: 'R',
            color: 'A VERY LONG COLOUR NAME INDEED',
            printCode: 'S_123456_11_06 15.59',
          ),
        ));

        expect(tester.takeException(), isNull);
        expect(find.text('ASL PODSHOX GILAMI ASL PODSHOX GILAMI'), findsOneWidget);
      });

      testWidgets('$name still draws a non-EAN value instead of failing',
          (tester) async {
        await tester.pumpWidget(MaterialApp(home: build('TGC-00005984')));

        expect(tester.takeException(), isNull);
        final product = productBarcodeOn(tester);
        expect(product.barcode.name, 'CODE 128');
        expect(String.fromCharCodes(product.data), 'TGC-00005984');
      });
    });
  });
}

final scanCodeName = Barcode.dataMatrix().name;

/// The label's product barcode, on a label with no carpet number.
BarcodeWidget productBarcodeOn(WidgetTester tester) => tester
    .widgetList<BarcodeWidget>(find.byType(BarcodeWidget))
    .singleWhere((w) => w.barcode.name != scanCodeName);
