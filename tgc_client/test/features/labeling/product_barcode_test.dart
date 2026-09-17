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
      testWidgets('$name draws the product barcode as EAN-13', (tester) async {
        await tester.pumpWidget(MaterialApp(home: build('2984200059847')));

        expect(tester.takeException(), isNull);
        final product = productBarcodeOn(tester);
        expect(product.barcode.name, 'EAN 13');
        expect(String.fromCharCodes(product.data), '2984200059847');
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

/// The label's product barcode, i.e. the one next to the QR code.
BarcodeWidget productBarcodeOn(WidgetTester tester) => tester
    .widgetList<BarcodeWidget>(find.byType(BarcodeWidget))
    .singleWhere((w) => w.barcode.name != 'QR-Code');
