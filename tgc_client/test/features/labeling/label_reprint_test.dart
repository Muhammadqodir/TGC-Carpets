import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/features/labeling/data/datasources/labeling_remote_datasource.dart';
import 'package:tgc_client/features/labeling/domain/entities/labeling_item_entity.dart';
import 'package:tgc_client/features/labeling/domain/repositories/labeling_repository.dart';
import 'package:tgc_client/features/labeling/presentation/bloc/labeling_bloc.dart';
import 'package:tgc_client/features/labeling/presentation/bloc/labeling_event.dart';
import 'package:tgc_client/features/labeling/presentation/bloc/labeling_state.dart';
import 'package:tgc_client/features/scanner/data/models/scanned_item_model.dart';
import 'package:tgc_client/features/scanner/presentation/pages/scanner_page.dart';

/// Labels that are not new carpets: a replacement for a torn label is sent as
/// a reprint, a print on a finished line still reaches the server (which
/// records it instead of counting), and a failed count retries with its key.
void main() {
  LabelingItemEntity line({int produced = 0, int planned = 2}) => LabelingItemEntity(
        id: 9121,
        batchId: 1323,
        plannedQuantity: planned,
        producedQuantity: produced,
        variantId: 5984,
        productName: '1568',
      );

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('LabelingBloc', () {
    test('a print on a finished line still goes to the server', () async {
      final repo = _FakeRepository();
      final bloc = LabelingBloc(repository: repo)..emit(LabelingLoaded(items: [line(produced: 2)]));

      bloc.add(const LabelingPrintRequested(batchId: 1323, itemId: 9121));
      await settle();

      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.reprint, isFalse);
      await bloc.close();
    });

    test('a reprint is flagged and never takes the pending key of a count', () async {
      final repo = _FakeRepository();
      final bloc = LabelingBloc(repository: repo)..emit(LabelingLoaded(items: [line(produced: 1)]));

      bloc.add(const LabelingPrintRequested(batchId: 1323, itemId: 9121, reprint: true));
      await settle();
      bloc.add(const LabelingPrintRequested(batchId: 1323, itemId: 9121));
      await settle();

      expect(repo.calls.map((c) => c.reprint), [true, false]);
      expect(repo.calls[0].key, isNot(repo.calls[1].key));
      await bloc.close();
    });

    test('a failed count retries with the same key', () async {
      final repo = _FakeRepository(failFirst: true);
      final bloc = LabelingBloc(repository: repo)..emit(LabelingLoaded(items: [line()]));

      bloc.add(const LabelingPrintRequested(batchId: 1323, itemId: 9121));
      await settle();
      expect((bloc.state as LabelingLoaded).pendingKeys[9121], repo.calls.single.key);

      bloc.add(const LabelingPrintRequested(batchId: 1323, itemId: 9121));
      await settle();

      expect(repo.calls, hasLength(2));
      expect(repo.calls[1].key, repo.calls[0].key);
      await bloc.close();
    });
  });

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

class _Call {
  _Call(this.key, this.reprint);
  final String key;
  final bool reprint;
}

class _FakeRepository implements LabelingRepository {
  _FakeRepository({this.failFirst = false});

  final bool failFirst;
  final calls = <_Call>[];

  @override
  Future<Either<Failure, LabelingItemEntity>> printLabel({
    required int batchId,
    required int itemId,
    required String idempotencyKey,
    bool reprint = false,
  }) async {
    calls.add(_Call(idempotencyKey, reprint));
    if (failFirst && calls.length == 1) return const Left(NetworkFailure('offline'));
    return Right(LabelingItemEntity(
      id: itemId,
      batchId: batchId,
      plannedQuantity: 2,
      producedQuantity: 1,
      variantId: 5984,
      productName: '1568',
    ));
  }

  @override
  Future<Either<Failure, List<LabelingItemEntity>>> getLabelingItems() async => const Right([]);
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
