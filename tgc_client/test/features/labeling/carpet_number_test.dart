import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgc_client/core/error/exceptions.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/features/labeling/data/datasources/labeling_remote_datasource.dart';
import 'package:tgc_client/features/labeling/data/services/carpet_number_pool.dart';
import 'package:tgc_client/features/labeling/data/services/print_history_service.dart';
import 'package:tgc_client/features/labeling/domain/carpet_number.dart';
import 'package:tgc_client/features/labeling/domain/entities/carpet_number_block.dart';
import 'package:tgc_client/features/labeling/domain/entities/labeling_item_entity.dart';
import 'package:tgc_client/features/labeling/domain/repositories/labeling_repository.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/labels/print_label_70_50.dart';

/// Every new label carries its own number, from a block this PC holds ahead of
/// printing. A number used or lost is never used again, whatever happens.
void main() {
  group('carpetNumber', () {
    test('matches the server, digit for digit', () {
      // CarpetNumberTest.php pins the same numbers.
      expect(carpetNumber(1), '210000000010');
      expect(carpetNumber(123456789), '211234567898');
    });

    test('checks its digits', () {
      expect(isCarpetNumber('210000000010'), isTrue);
      expect(isCarpetNumber('210000000011'), isFalse);
      expect(isCarpetNumber('220000000017'), isFalse);
      expect(isCarpetNumber('21000000001'), isFalse);
    });

    test('refuses a serial that does not fit', () {
      expect(() => carpetNumber(0), throwsArgumentError);
      expect(() => carpetNumber(carpetNumberMaxSerial + 1), throwsArgumentError);
    });
  });

  group('CarpetNumberPool', () {
    late SharedPreferences prefs;
    late _FakeBlocks server;

    CarpetNumberPool newPool({int topUpBelow = 2}) =>
        CarpetNumberPool(repository: server, prefs: prefs, topUpBelow: topUpBelow);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      server = _FakeBlocks(blockSize: 5);
    });

    test('hands out numbers in order, each once', () async {
      final pool = newPool(topUpBelow: 0);

      expect(await pool.take(), carpetNumber(1));
      expect(await pool.take(), carpetNumber(2));
      expect(pool.remaining, 3);
    });

    test('two prints at once get different numbers from one request', () async {
      final pool = newPool(topUpBelow: 0);

      final numbers = await Future.wait([pool.take(), pool.take()]);

      expect(numbers.toSet(), {carpetNumber(1), carpetNumber(2)});
      expect(server.requests, 1);
    });

    test('a restart never repeats a number', () async {
      final before = newPool(topUpBelow: 0);
      await before.take();
      await before.take();

      final after = newPool(topUpBelow: 0);

      expect(await after.take(), carpetNumber(3));
      expect(server.requests, 1);
    });

    test('tops up in the background before it runs out', () async {
      final pool = newPool(topUpBelow: 3);
      for (var i = 0; i < 3; i++) {
        await pool.take();
      }
      await pumpEventQueue();

      expect(server.requests, 2);
      expect(pool.remaining, 7);
    });

    test('topUp leaves a full pool alone', () async {
      final pool = newPool(topUpBelow: 3);
      pool.topUp();
      await pumpEventQueue();
      pool.topUp();
      await pumpEventQueue();

      expect(server.requests, 1);
    });

    test('offline, it prints what it holds, then says so instead of guessing', () async {
      final pool = newPool(topUpBelow: 0);
      pool.topUp();
      expect(await pool.take(), carpetNumber(1));
      server.offline = true;

      for (var serial = 2; serial <= 5; serial++) {
        expect(await pool.take(), carpetNumber(serial));
      }
      expect(await pool.take(), isNull);

      server.offline = false;
      expect(await pool.take(), carpetNumber(6));
    });

    test('a corrupt file does not block printing', () async {
      await prefs.setString('carpet_number_pool_v1', 'not json');

      expect(await newPool(topUpBelow: 0).take(), carpetNumber(1));
    });
  });

  group('requesting a block', () {
    Future<CarpetNumberBlock> ask(Object? body) => LabelingRemoteDataSourceImpl(
          Dio(BaseOptions(baseUrl: 'https://erp.test/api/v1'))..httpClientAdapter = _JsonServer(body),
        ).requestCarpetNumberBlock();

    test('reads the server\'s answer', () async {
      final block = await ask({'first_serial': 501, 'last_serial': 1000});

      expect(block.firstSerial, 501);
      expect(block.lastSerial, 1000);
    });

    test('rejects anything that does not look like a block', () async {
      for (final body in [
        {'message': 'ok'},
        {'first_serial': '1', 'last_serial': 500},
        {'first_serial': 500, 'last_serial': 1},
        {'first_serial': 0, 'last_serial': 500},
        {'first_serial': 1, 'last_serial': carpetNumberMaxSerial + 1},
      ]) {
        await expectLater(ask(body), throwsA(isA<ServerException>()), reason: '$body');
      }
    });
  });

  group('print history', () {
    late PrintHistoryService history;

    const item = LabelingItemEntity(
      id: 9121,
      batchId: 1323,
      plannedQuantity: 4,
      producedQuantity: 0,
      variantId: 5984,
      productName: '1568',
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      history = PrintHistoryService(await SharedPreferences.getInstance());
    });

    test('keeps one entry per label, so a reprint repeats the right number', () async {
      await history.addToHistory(item, carpetNumber: carpetNumber(1));
      await history.addToHistory(item, carpetNumber: carpetNumber(2));

      final numbers = (await history.getHistory()).map((h) => h.carpetNumber).toSet();

      expect(numbers, {carpetNumber(1), carpetNumber(2)});
    });

    test('an entry from before labels had numbers gives way to a new label', () async {
      await history.addToHistory(item);
      await history.addToHistory(item, carpetNumber: carpetNumber(1));

      final entries = await history.getHistory();

      expect(entries.map((h) => h.carpetNumber), [carpetNumber(1)]);
    });

    test('survives being saved and read back', () async {
      await history.addToHistory(item, carpetNumber: carpetNumber(7));

      expect((await history.getHistory()).single.carpetNumber, carpetNumber(7));
    });
  });

  group('the label', () {
    testWidgets('prints the number as a second Code 128', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: PrintLabel7050(
          barcodeValue: '2984200059847',
          carpetBarcode: carpetNumber(1),
          qrData: 'P1 I1',
        ),
      ));

      expect(tester.takeException(), isNull);
      final printed = tester
          .widgetList<BarcodeWidget>(find.byType(BarcodeWidget))
          .where((w) => w.barcode.name == 'CODE 128')
          .map((w) => String.fromCharCodes(w.data));
      expect(printed, ['2984200059847', '210000000010']);
    });
  });
}

/// Issues blocks like the server: never overlapping.
class _FakeBlocks implements LabelingRepository {
  _FakeBlocks({required this.blockSize});

  final int blockSize;
  int requests = 0;
  bool offline = false;
  int _issued = 0;

  @override
  Future<Either<Failure, CarpetNumberBlock>> requestCarpetNumberBlock() async {
    if (offline) return const Left(NetworkFailure('Serverga ulanib bo\'lmadi.'));
    requests++;
    final block = CarpetNumberBlock(firstSerial: _issued * blockSize + 1, lastSerial: (_issued + 1) * blockSize);
    _issued++;
    return Right(block);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _JsonServer implements HttpClientAdapter {
  _JsonServer(this.body);

  final Object? body;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
