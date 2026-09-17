import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/labeling/domain/label_qr_format.dart';
import 'package:tgc_client/features/scanner/data/models/scanned_item_model.dart';
import 'package:tgc_client/features/scanner/presentation/pages/scanner_page.dart';

/// The home-page scanner: which labels it looks up, and what it shows about
/// the carpet — who printed the line's labels and when, the order, stock.
void main() {
  group('isProductionLabelQr', () {
    test('accepts every label shape on real carpets', () {
      expect(isProductionLabelQr('P1323 I9121'), isTrue);
      expect(isProductionLabelQr('PB12 PBI345'), isTrue);
      expect(isProductionLabelQr('PB{12} PBI{345}'), isTrue);
      expect(isProductionLabelQr('TGC-U-00001234'), isTrue);
    });

    test('rejects anything else without a request', () {
      expect(isProductionLabelQr('PB{12} VAR{42}'), isFalse);
      expect(isProductionLabelQr('2984200059847'), isFalse);
      expect(isProductionLabelQr('https://erp.tgc-carpets.uz'), isFalse);
      expect(isProductionLabelQr('P12I345'), isFalse);
    });
  });

  Map<String, dynamic> response({bool withDetails = true}) => {
        'unit': null,
        'item': {
          'id': 9121,
          'planned_quantity': 2,
          'produced_quantity': 2,
          'defect_quantity': 0,
          'warehouse_received_quantity': 1,
        },
        'product': {'name': '1568', 'size_label': '200×300', 'barcode': '2984200059847'},
        'production_batch': {
          'id': 1323,
          'status': 'completed',
          'type': 'by_order',
          if (withDetails) 'created_at': '2026-09-16T04:00:00.000000Z',
        },
        'destination': {
          'type': 'client',
          'client_name': 'A MIJOZ',
          'region': 'Toshkent',
          if (withDetails) ...{
            'contact_name': 'Anvar',
            'phone': '+998901234567',
            'order_id': 14,
            'order_status': 'on_production',
            'order_date': '2026-09-01',
            'ordered_quantity': 3,
            'shipped_quantity': 1,
          },
        },
        if (withDetails) ...{
          'label_prints': {
            'before_tracking': 1,
            'prints': [
              {'printed_at': '2026-09-17T05:15:00.000000Z', 'printed_by_name': '1 SMENA (YORLIQ)'},
              {'printed_at': '2026-09-17T16:40:00.000000Z', 'printed_by_name': '2 SMENA (YORLIQ)'},
            ],
          },
          'reattribution': {'from_client_name': 'B MIJOZ', 'shipment_id': 4},
          'stock_quantity': 3,
        },
      };

  group('ScannedItemModel', () {
    test('reads prints, order, reattribution and stock', () {
      final item = ScannedItemModel.fromJson(response());

      expect(item.labelPrints!.total, 3);
      expect(item.labelPrints!.prints.last.printedByName, '2 SMENA (YORLIQ)');
      expect(item.destination!.orderId, 14);
      expect(item.destination!.shippedQuantity, 1);
      expect(item.reattribution!.fromClientName, 'B MIJOZ');
      expect(item.stockQuantity, 3);
      expect(item.productionBatch.createdAt, '2026-09-16T04:00:00.000000Z');
    });

    test('a server without the new fields still parses', () {
      final item = ScannedItemModel.fromJson(response(withDetails: false));

      expect(item.labelPrints, isNull);
      expect(item.reattribution, isNull);
      expect(item.stockQuantity, isNull);
      expect(item.destination!.orderId, isNull);
    });
  });

  group('ScanResultView', () {
    String local(String iso) {
      final d = DateTime.parse(iso).toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
    }

    testWidgets('shows who printed each label and when, in local time', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ScanResultView(item: ScannedItemModel.fromJson(response()), onReset: () {}),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Yorliq chop etilishi'), findsOneWidget);
      expect(find.text('3 ta'), findsOneWidget);
      expect(find.text(local('2026-09-17T05:15:00.000000Z')), findsOneWidget);
      expect(find.text('1 SMENA (YORLIQ)'), findsOneWidget);
      expect(find.text(local('2026-09-17T16:40:00.000000Z')), findsOneWidget);
      expect(find.text('2 SMENA (YORLIQ)'), findsOneWidget);
      expect(find.text('1 ta (kim va qachon yozilmagan)'), findsOneWidget);
      expect(find.text('+998901234567'), findsOneWidget);
      expect(find.text('01.09.2026'), findsOneWidget);
      expect(find.text('1 / 3 dona'), findsOneWidget);
      expect(find.text('Ishlab chiqarilmoqda'), findsOneWidget);
      expect(find.text('B MIJOZ (yuk xati #4)'), findsOneWidget);
      expect(find.text('3 dona'), findsOneWidget);
    });

    testWidgets('an older server response shows no empty cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ScanResultView(
              item: ScannedItemModel.fromJson(response(withDetails: false)), onReset: () {}),
        ),
      ));

      expect(tester.takeException(), isNull);
      expect(find.text('Yorliq chop etilishi'), findsNothing);
      expect(find.text('Omborda hozir'), findsNothing);
    });
  });
}
