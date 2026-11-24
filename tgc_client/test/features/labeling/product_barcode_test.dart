import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/labeling/domain/product_barcode.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/labels/print_label_70_50.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/labels/print_label_70_50_arab.dart';

/// The label's product barcode is 8 digits, the same number the backend
/// stores (ProductBarcodeTest in tgc_backend uses the same table), and never
/// falls back to the "TGC-" text some clients' systems reject.
void main() {
  group('productBarcode', () {
    const sameAsBackend = {
      1: '50000012',
      42: '50000425',
      5984: '50059843',
      999999: '59999997',
    };

    sameAsBackend.forEach((id, expected) {
      test('variant $id → $expected', () {
        expect(productBarcode(id), expected);
        expect(isEan8(productBarcode(id)), isTrue);
        expect(isProductBarcode(productBarcode(id)), isTrue);
      });
    });

    test('ids that do not fit are refused rather than truncated', () {
      expect(() => productBarcode(0), throwsArgumentError);
      expect(() => productBarcode(1000000), throwsArgumentError);
    });
  });

  group('check digits', () {
    test('agree with real retail codes', () {
      expect(isEan13('4006381333931'), isTrue);
      expect(isEan8('96385074'), isTrue); // GS1's own EAN-8 example
    });

    test('reject a wrong check digit, letters and wrong lengths', () {
      expect(isEan8('50059842'), isFalse);
      expect(isEan13('2984200059846'), isFalse);
      expect(isEan13('TGC-00005984'), isFalse);
      expect(isEan8('5005984'), isFalse);
      expect(isEan8(''), isFalse);
    });
  });

  group('isProductBarcode', () {
    test('knows the current code and the 13-digit one before it', () {
      expect(isProductBarcode('50059843'), isTrue);
      expect(isProductBarcode('2984200059847'), isTrue);
    });

    test('is not fooled by other codes on or near a label', () {
      expect(isProductBarcode('96385074'), isFalse); // someone else's EAN-8
      expect(isProductBarcode('4006381333931'), isFalse);
      expect(isProductBarcode('210000000010'), isFalse); // a carpet number
      expect(isProductBarcode('P12 I5984'), isFalse);
    });
  });

  group('labelBarcodeValue', () {
    test('prints the server value when it is already the 8 digits', () {
      expect(labelBarcodeValue(stored: '50059843', variantId: 5984), '50059843');
    });

    test('older values saved in print history reprint as the 8 digits', () {
      for (final old in ['2984200059847', 'TGC-00005984', 'TGC-VAR-00005984']) {
        expect(labelBarcodeValue(stored: old, variantId: 5984), '50059843');
      }
    });

    test('no stored value falls back to the derived one', () {
      expect(labelBarcodeValue(stored: null, variantId: 42), '50000425');
      expect(labelBarcodeValue(stored: '', variantId: 42), '50000425');
    });
  });

  group('label widgets', () {
    final labels = <String, Widget Function(String)>{
      'PrintLabel7050': (value) => PrintLabel7050(
            barcodeValue: value,
            productName: '1568',
            quality: 'Ronaldo',
            color: 'Beige',
            sizeLabel: '200x300',
            edgeCode: 'R',
          ),
      'PrintLabel7050Arab': (value) => PrintLabel7050Arab(
            barcodeValue: value,
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
        await tester.pumpWidget(MaterialApp(home: build('50059843')));

        expect(tester.takeException(), isNull);
        final product = productBarcodeOn(tester);
        expect(product.barcode.name, 'CODE 128');
        expect(String.fromCharCodes(product.data), '50059843');
      });

      // Workers' scanners read the square code instead of the carpet
      // number beside it, so it was dropped in November 2026.
      testWidgets('$name draws no square code', (tester) async {
        await tester.pumpWidget(MaterialApp(home: build('50059843')));

        final kinds = tester
            .widgetList<BarcodeWidget>(find.byType(BarcodeWidget))
            .map((w) => w.barcode.name)
            .toSet();
        expect(kinds, {'CODE 128'});
      });

      testWidgets('$name draws a long value without overflowing',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: PrintLabel7050(
            barcodeValue: '50059843',
            carpetBarcode: '210000012345',
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

/// The label's product barcode, on a label with no carpet number.
BarcodeWidget productBarcodeOn(WidgetTester tester) =>
    tester.widget<BarcodeWidget>(find.byType(BarcodeWidget));
