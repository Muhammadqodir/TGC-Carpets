import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgc_client/core/error/exceptions.dart';
import 'package:tgc_client/core/error/failures.dart';
import 'package:tgc_client/features/labeling/data/datasources/labeling_remote_datasource.dart';
import 'package:tgc_client/features/labeling/data/services/label_print_queue.dart';
import 'package:tgc_client/features/labeling/domain/entities/label_print_result.dart';
import 'package:tgc_client/features/labeling/domain/entities/labeling_item_entity.dart';
import 'package:tgc_client/features/labeling/domain/repositories/labeling_repository.dart';
import 'package:tgc_client/features/labeling/presentation/bloc/labeling_bloc.dart';
import 'package:tgc_client/features/labeling/presentation/bloc/labeling_event.dart';
import 'package:tgc_client/features/labeling/presentation/bloc/labeling_state.dart';

/// Local-first label printing. The two ways the old flow lost carpets on
/// production (2026-09-01..10-29, 197 labels) are pinned down here: a
/// failed request's key reused by the next carpet, and a second tap sending
/// the key of a request still in flight.
void main() {
  const shift1 = 5;
  const shift2 = 6;

  LabelingItemEntity line({int id = 9121, int produced = 0, int planned = 4}) => LabelingItemEntity(
        id: id,
        batchId: 1323,
        plannedQuantity: planned,
        producedQuantity: produced,
        variantId: 5984,
        productName: '1568',
        sizeLength: 300,
        sizeWidth: 200,
      );

  late SharedPreferences prefs;
  late _FakeServerRepo server;
  late int? user;
  final queues = <LabelPrintQueue>[];

  LabelPrintQueue newQueue() {
    final q = LabelPrintQueue(
      repository: server,
      prefs: prefs,
      currentUserId: () => user,
      verifyAfter: Duration.zero,
      tick: const Duration(hours: 1),
    )..start();
    queues.add(q);
    return q;
  }

  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Hold, print, release: what the labeling page does for one tap.
  Future<void> printOne(LabelPrintQueue q, LabelingItemEntity item, {bool reprint = false}) async {
    final held = await q.hold(item: item, userId: user!, reprint: reprint);
    await q.release(held.key);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    server = _FakeServerRepo();
    user = shift1;
  });

  tearDown(() {
    for (final q in queues) {
      q.dispose();
    }
    queues.clear();
  });

  group('LabelPrintQueue', () {
    test('a print is sent with its print time and leaves the queue once verified', () async {
      final q = newQueue();
      await printOne(q, line());
      await settle();

      expect(server.counted, 1);
      expect(server.calls.single.printedAt, isNotNull);
      expect(server.verified, [server.calls.single.key]);
      expect(q.entries, isEmpty);
    });

    test('a failed request is retried with its own key, and the next carpet gets a new one', () async {
      // The old flow: tap 1 fails (label printed), tap 2 for the next carpet
      // reused tap 1's key — two labels, one count.
      server.offline = true;
      final q = newQueue();
      await printOne(q, line());
      await settle();
      expect(server.counted, 0);
      expect(q.unsentCount, 1);

      await printOne(q, line());
      server.offline = false;
      q.wake();
      await settle();

      expect(server.counted, 2);
      expect(server.recordedKeys, hasLength(2));
      expect(q.entries, isEmpty);
    });

    test('a request whose answer was lost counts once, and the next label still counts', () async {
      server.loseNextAnswer = true; // recorded on the server, timeout on the app
      final q = newQueue();
      await printOne(q, line());
      await settle();
      expect(server.counted, 1);
      expect(q.unsentCount, 1);

      q.wake();
      await settle();
      await printOne(q, line());
      await settle();

      expect(server.counted, 2);
      expect(q.entries, isEmpty);
    });

    test('two taps while the first request is in flight are two labels', () async {
      server.hold = Completer<void>();
      final q = newQueue();
      await printOne(q, line());
      await settle();
      await printOne(q, line());
      server.hold!.complete();
      await settle();

      expect(server.counted, 2);
      expect(server.calls.map((c) => c.key).toSet(), hasLength(2));
    });

    test('a print the printer refused is dropped, not sent', () async {
      final q = newQueue();
      final held = await q.hold(item: line(), userId: shift1);
      await q.discard(held.key);
      await settle();

      expect(server.calls, isEmpty);
      expect(q.entries, isEmpty);
    });

    test('a garbled 200 is not taken as recorded', () async {
      // A proxy page or a cut-off body: the datasource refuses it...
      final dio = Dio(BaseOptions(baseUrl: 'https://erp.test/api/v1'))..httpClientAdapter = _HtmlServer();
      final source = LabelingRemoteDataSourceImpl(dio);
      await expectLater(
        source.printLabel(batchId: 1323, itemId: 9121, idempotencyKey: 'k1'),
        throwsA(isA<ServerException>()),
      );

      // ...and the queue keeps the label and sends it again.
      server.garbleNext = true;
      final q = newQueue();
      await printOne(q, line());
      await settle();
      expect(q.unsentCount, 1);
      q.wake();
      await settle();
      expect(server.counted, 1);
      expect(q.entries, isEmpty);
    });

    test('a key the server does not have after a 200 is sent again', () async {
      server.forgetOnVerify = true;
      final q = newQueue();
      await printOne(q, line());
      await settle();

      expect(server.calls, hasLength(2));
      expect(server.calls[0].key, server.calls[1].key);
      expect(q.entries, isEmpty);
    });

    test('a line the server refuses for good does not hold up the labels after it', () async {
      server.notFoundItems.add(1);
      final q = newQueue();
      await printOne(q, line(id: 1));
      await printOne(q, line(id: 2));
      await settle();

      expect(server.recordedKeys, hasLength(1));
      expect(q.failedCount, 1);
      expect(q.entries.single.itemId, 1);
    });

    test('the queue survives a restart, a label caught mid-print included', () async {
      server.offline = true;
      final q1 = newQueue();
      await printOne(q1, line());
      await q1.hold(item: line(), userId: shift1); // app closed while printing
      await settle();
      q1.dispose();

      server.offline = false;
      final q2 = newQueue();
      await settle();

      expect(server.counted, 2);
      expect(q2.entries, isEmpty);
    });

    test("another shift's labels wait until that shift logs in", () async {
      server.offline = true;
      final q = newQueue();
      await printOne(q, line());
      server.offline = false;
      user = shift2;
      q.wake();
      await settle();
      expect(server.counted, 0);
      expect(server.calls, hasLength(1)); // only the offline attempt

      user = shift1;
      q.wake();
      await settle();
      expect(server.counted, 1);
    });

    test('a reprint is never counted on screen and is flagged to the server', () async {
      server.offline = true;
      final q = newQueue();
      await printOne(q, line(produced: 1), reprint: true);
      expect(q.localCountFor(9121), 0);

      server.offline = false;
      q.wake();
      await settle();
      expect(server.calls.last.reprint, isTrue);
      expect(server.counted, 0);
    });
  });

  group('LabelingBloc', () {
    test('counts a print on screen at once, before the server answers', () async {
      server.offline = true;
      server.items = [line(planned: 2)];
      final q = newQueue();
      final bloc = LabelingBloc(repository: server, queue: q)..add(const LabelingLoadRequested());
      await settle();

      await printOne(q, (bloc.state as LabelingLoaded).items.single);
      await settle();
      expect((bloc.state as LabelingLoaded).items.single.producedQuantity, 1);

      // The second carpet completes the line: it leaves the list offline too.
      await printOne(q, (bloc.state as LabelingLoaded).items.single);
      await settle();
      expect((bloc.state as LabelingLoaded).items, isEmpty);

      server.offline = false;
      q.wake();
      await settle();
      expect(server.counted, 2);
      await bloc.close();
    });

    test("takes the server's count when a label is confirmed", () async {
      server.items = [line(planned: 4)];
      server.producedBefore[9121] = 2; // another PC printed two meanwhile
      final q = newQueue();
      final bloc = LabelingBloc(repository: server, queue: q)..add(const LabelingLoadRequested());
      await settle();

      await printOne(q, (bloc.state as LabelingLoaded).items.single);
      await settle();

      expect((bloc.state as LabelingLoaded).items.single.producedQuantity, 3);
      await bloc.close();
    });
  });
}

class _Call {
  _Call(this.key, this.itemId, this.reprint, this.printedAt);
  final String key;
  final int itemId;
  final bool reprint;
  final DateTime? printedAt;
}

/// The server side of print-label, with its idempotency: a key it has
/// seen replays instead of counting again.
class _FakeServerRepo implements LabelingRepository {
  final calls = <_Call>[];
  final recordedKeys = <String>{};
  final notFoundItems = <int>{};
  final producedBefore = <int, int>{};
  final produced = <int, int>{};
  List<LabelingItemEntity> items = const [];
  int counted = 0;
  bool offline = false;
  bool loseNextAnswer = false;
  bool garbleNext = false;
  bool forgetOnVerify = false;
  Completer<void>? hold;
  final verified = <String>[];

  @override
  Future<Either<Failure, LabelPrintResult>> printLabel({
    required int batchId,
    required int itemId,
    required String idempotencyKey,
    bool reprint = false,
    DateTime? printedAt,
  }) async {
    calls.add(_Call(idempotencyKey, itemId, reprint, printedAt));
    if (hold != null && !hold!.isCompleted) await hold!.future;
    if (offline) return const Left(NetworkFailure('Serverga ulanib bo\'lmadi.'));
    if (notFoundItems.contains(itemId)) return const Left(ServerFailure('Not found', statusCode: 404));
    if (garbleNext) {
      garbleNext = false;
      return const Left(ServerFailure('Server javobi noto\'g\'ri, qayta yuboriladi'));
    }

    if (recordedKeys.add(idempotencyKey) && !reprint) {
      counted++;
      produced[itemId] = (produced[itemId] ?? producedBefore[itemId] ?? 0) + 1;
    }
    if (loseNextAnswer) {
      loseNextAnswer = false;
      return const Left(NetworkFailure('So\'rov vaqti tugadi.'));
    }
    return Right(LabelPrintResult(
      item: LabelingItemEntity(
        id: itemId,
        batchId: batchId,
        plannedQuantity: 4,
        producedQuantity: produced[itemId] ?? producedBefore[itemId] ?? 0,
        variantId: 5984,
        productName: '1568',
      ),
      counted: !reprint,
    ));
  }

  @override
  Future<Either<Failure, Set<String>>> verifyPrintedLabels(List<String> keys) async {
    verified.addAll(keys);
    if (forgetOnVerify) {
      forgetOnVerify = false;
      recordedKeys.removeAll(keys);
      counted -= keys.length;
    }
    return Right(keys.where(recordedKeys.contains).toSet());
  }

  @override
  Future<Either<Failure, List<LabelingItemEntity>>> getLabelingItems() async => Right(items);
}

class _HtmlServer implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(
      jsonEncode({'message': 'ok'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
