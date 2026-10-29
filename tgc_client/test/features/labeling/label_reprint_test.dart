import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/features/labeling/data/datasources/labeling_remote_datasource.dart';
import 'package:tgc_client/features/scanner/data/models/scanned_item_model.dart';
import 'package:tgc_client/features/scanner/presentation/pages/scanner_page.dart';

/// Labels that are not new carpets: a replacement for a torn label is sent as
/// a reprint, and the scan screen tells reprints apart. The queue that sends
/// every print is covered in label_print_queue_test.dart.
void main() {
  group('LabelingRemoteDataSource', () {
    test('sends reprint only for a reprint', () async {
      final server = _FakeServer();
      final dio = Dio(BaseOptions(baseUrl: 'https://erp.test/api/v1'))..httpClientAdapter = server;
      final source = LabelingRemoteDataSourceImpl(dio);

      await source.printLabel(batchId: 1323, itemId: 9121, idempotencyKey: 'k1');
      await source.printLabel(batchId: 1323, itemId: 9121, idempotencyKey: 'k2', reprint: true);

      expect(server.bodies[0], {'idempotency_key': 'k1'});
      expect(server.bodies[1], {'idempotency_key': 'k2', 'reprint': true});
    });
  });

  group('scan screen', () {
    testWidgets('marks reprints among the prints', (tester) async {
      tester.view.physicalSize = const Size(1080, 6000);
      addTearDown(tester.view.reset);
      final item = ScannedItemModel.fromJson({
        'unit': null,
        'item': {'id': 9121, 'planned_quantity': 1, 'produced_quantity': 1},
        'product': {'name': '1568'},
        'production_batch': {'id': 1323, 'status': 'completed', 'type': 'for_stock'},
        'destination': {'type': 'warehouse'},
        'label_prints': {
          'before_tracking': 0,
          'prints': [
            {'printed_at': '2026-09-17T05:15:00.000000Z', 'printed_by_name': '1 SMENA (YORLIQ)', 'kind': 'print'},
            {'printed_at': '2026-09-17T05:16:00.000000Z', 'printed_by_name': '1 SMENA (YORLIQ)', 'kind': 'reprint'},
            {'printed_at': '2026-09-17T16:40:00.000000Z', 'printed_by_name': '2 SMENA (YORLIQ)', 'kind': 'over_target'},
          ],
        },
      });

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ScanResultView(item: item, onReset: () {}))));

      expect(find.text('3 ta (shundan qayta: 2)'), findsOneWidget);
      expect(find.text('1 SMENA (YORLIQ)'), findsOneWidget);
      expect(find.text('1 SMENA (YORLIQ) · qayta chop etish'), findsOneWidget);
      expect(find.text('2 SMENA (YORLIQ) · rejadan ortiq'), findsOneWidget);
    });
  });
}

class _FakeServer implements HttpClientAdapter {
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    bodies.add(Map<String, dynamic>.from(options.data as Map));
    return ResponseBody.fromString(
      jsonEncode({
        'data': {'id': 9121, 'production_batch_id': 1323, 'planned_quantity': 2, 'produced_quantity': 1},
        'unit': null,
        'counted': false,
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
