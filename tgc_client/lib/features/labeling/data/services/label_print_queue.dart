import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/labeling_item_entity.dart';
import '../../domain/repositories/labeling_repository.dart';

/// Where one queued label is on its way to the server.
enum QueuedPrintStatus {
  /// Held while the label is rendered and sent to the printer. Not sent:
  /// a print that fails is dropped, not counted.
  printing,

  /// Printed, waiting to be sent.
  pending,

  /// The server answered 200; waiting for [LabelPrintQueue.verify] to
  /// confirm the key is on record.
  sent,

  /// The server refused it for good (line deleted, validation). Kept so
  /// the operator sees it; never dropped on its own.
  failed,
}

/// One physical label. Its key is minted when the label is printed and
/// never shared with another label, so a resend can only ever replay this
/// label and never swallow the next carpet.
class QueuedLabelPrint {
  QueuedLabelPrint({
    required this.key,
    required this.batchId,
    required this.itemId,
    required this.userId,
    required this.reprint,
    required this.countsLocally,
    required this.printedAt,
    required this.productName,
    this.sizeLabel,
    this.status = QueuedPrintStatus.printing,
    this.attempts = 0,
    this.lastError,
    this.sentAt,
  });

  final String key;
  final int batchId;
  final int itemId;

  /// The shift account that printed it. Sent only while that account is
  /// logged in, so the carpet is never put on the next shift.
  final int userId;
  final bool reprint;

  /// Whether the screen counts it as a carpet until the server answers:
  /// false for a reprint and for a print past the plan.
  final bool countsLocally;
  final DateTime printedAt;
  final String productName;
  final String? sizeLabel;

  QueuedPrintStatus status;
  int attempts;
  String? lastError;
  DateTime? sentAt;

  Map<String, dynamic> toJson() => {
        'key': key,
        'batch_id': batchId,
        'item_id': itemId,
        'user_id': userId,
        'reprint': reprint,
        'counts_locally': countsLocally,
        'printed_at': printedAt.toIso8601String(),
        'product_name': productName,
        'size_label': sizeLabel,
        'status': status.name,
        'attempts': attempts,
        'last_error': lastError,
        'sent_at': sentAt?.toIso8601String(),
      };

  factory QueuedLabelPrint.fromJson(Map<String, dynamic> json) => QueuedLabelPrint(
        key: json['key'] as String,
        batchId: json['batch_id'] as int,
        itemId: json['item_id'] as int,
        userId: json['user_id'] as int,
        reprint: json['reprint'] as bool? ?? false,
        countsLocally: json['counts_locally'] as bool? ?? false,
        printedAt: DateTime.parse(json['printed_at'] as String),
        productName: json['product_name'] as String? ?? '',
        sizeLabel: json['size_label'] as String?,
        status: QueuedPrintStatus.values.asNameMap()[json['status']] ?? QueuedPrintStatus.pending,
        attempts: json['attempts'] as int? ?? 0,
        lastError: json['last_error'] as String?,
        sentAt: json['sent_at'] == null ? null : DateTime.parse(json['sent_at'] as String),
      );
}

/// What changed in the queue. [confirmedItem] is the batch line as the
/// server has it after a label was accepted.
class LabelPrintQueueUpdate {
  const LabelPrintQueueUpdate({this.confirmedItem});

  final LabelingItemEntity? confirmedItem;
}

/// Local-first label printing: a tap prints at once and counts on screen at
/// once, and the record reaches the server from here, in the background,
/// in print order.
///
/// Every label is written to disk before it is printed and stays there
/// until the server has it. A failed, timed-out or garbled request is sent
/// again with the same key until it goes through; the app can be closed
/// or lose the network in between. After a 200 the key is checked once
/// more against the server ([verify]), and a key the server does not have
/// is sent again.
///
/// This replaces the old flow, which lost carpets two ways (197 labels on
/// production between 2026-09-01 and 2026-10-29): a key kept after a
/// failed request was reused by the NEXT carpet's print, and a second tap
/// while the first request was still in flight sent the same key; either
/// way two labels came out and the server counted one.
class LabelPrintQueue {
  LabelPrintQueue({
    required LabelingRepository repository,
    required SharedPreferences prefs,
    required int? Function() currentUserId,
    DateTime Function()? clock,
    this.verifyAfter = const Duration(seconds: 30),
    this.tick = const Duration(seconds: 30),
  })  : _repository = repository,
        _prefs = prefs,
        _currentUserId = currentUserId,
        _clock = clock ?? DateTime.now;

  static const _storageKey = 'label_print_queue_v1';
  static const _verifyBatch = 200;

  final LabelingRepository _repository;
  final SharedPreferences _prefs;
  final int? Function() _currentUserId;
  final DateTime Function() _clock;

  /// How long after a 200 a key is checked against the server.
  final Duration verifyAfter;

  /// How often the queue retries and verifies on its own.
  final Duration tick;

  final _updates = StreamController<LabelPrintQueueUpdate>.broadcast();
  final List<QueuedLabelPrint> _entries = [];

  Timer? _ticker;
  Timer? _retryTimer;
  bool _started = false;
  bool _draining = false;
  bool _drainAgain = false;
  bool _verifying = false;
  int _confirmations = 0;

  Stream<LabelPrintQueueUpdate> get updates => _updates.stream;

  List<QueuedLabelPrint> get entries => List.unmodifiable(_entries);

  /// Bumped on every label the server accepts. A labeling list fetched
  /// while it moved may predate one of them and is fetched again.
  int get confirmations => _confirmations;

  /// Labels not yet confirmed by the server, verified ones excluded.
  int get unsentCount => _entries.where((e) => e.status != QueuedPrintStatus.sent).length;

  int get failedCount => _entries.where((e) => e.status == QueuedPrintStatus.failed).length;

  /// Carpets on [itemId] the screen counts that the server's numbers do not
  /// include yet. A sent label is already in the line the server returned.
  int localCountFor(int itemId) => _entries
      .where((e) =>
          e.itemId == itemId &&
          e.countsLocally &&
          (e.status == QueuedPrintStatus.printing || e.status == QueuedPrintStatus.pending))
      .length;

  /// Loads the queue from disk and starts sending. A label left
  /// [QueuedPrintStatus.printing] by a crash most likely came out of the
  /// printer, so it is sent rather than lost.
  void start() {
    if (_started) return;
    _started = true;
    final raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        for (final e in jsonDecode(raw) as List) {
          final entry = QueuedLabelPrint.fromJson(e as Map<String, dynamic>);
          if (entry.status == QueuedPrintStatus.printing) entry.status = QueuedPrintStatus.pending;
          _entries.add(entry);
        }
      } catch (_) {
        // A corrupt queue file must not block printing.
      }
    }
    _ticker = Timer.periodic(tick, (_) => wake());
    wake();
  }

  /// Something changed that may let the queue through: the network came
  /// back, someone logged in, or the operator asked.
  void wake() {
    unawaited(_drain().then((_) => verify()));
  }

  /// Writes a label to disk before it is printed. Call [release] once the
  /// printer took it, or [discard] if it did not.
  Future<QueuedLabelPrint> hold({
    required LabelingItemEntity item,
    required int userId,
    bool reprint = false,
  }) =>
      _hold(QueuedLabelPrint(
        key: const Uuid().v4(),
        batchId: item.batchId,
        itemId: item.id,
        userId: userId,
        reprint: reprint,
        countsLocally: !reprint && item.remainingQuantity > 0,
        printedAt: _clock(),
        productName: item.productName,
        sizeLabel: item.sizeLabel,
      ));

  /// [hold] for a reprint from the print history, which has no line counts.
  Future<QueuedLabelPrint> holdReprint({
    required int batchId,
    required int itemId,
    required int userId,
    required String productName,
    String? sizeLabel,
  }) =>
      _hold(QueuedLabelPrint(
        key: const Uuid().v4(),
        batchId: batchId,
        itemId: itemId,
        userId: userId,
        reprint: true,
        countsLocally: false,
        printedAt: _clock(),
        productName: productName,
        sizeLabel: sizeLabel,
      ));

  Future<QueuedLabelPrint> _hold(QueuedLabelPrint entry) async {
    _entries.add(entry);
    await _changed();
    return entry;
  }

  Future<void> release(String key) async {
    final entry = _find(key);
    if (entry == null || entry.status != QueuedPrintStatus.printing) return;
    entry.status = QueuedPrintStatus.pending;
    await _changed();
    wake();
  }

  Future<void> discard(String key) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.key == key && e.status == QueuedPrintStatus.printing);
    if (_entries.length != before) await _changed();
  }

  /// Drops a label the server refused for good, by the operator's choice.
  Future<void> remove(String key) async {
    _entries.removeWhere((e) => e.key == key && e.status == QueuedPrintStatus.failed);
    await _changed();
  }

  /// Sends pending labels oldest first. Stops at the first transient
  /// failure, so labels stay in print order, and retries after a backoff.
  Future<void> _drain() async {
    if (_draining) {
      _drainAgain = true;
      return;
    }
    _draining = true;
    try {
      do {
        _drainAgain = false;
        while (true) {
          final userId = _currentUserId();
          if (userId == null) return;
          final next = _firstPending(userId);
          if (next == null) break;
          // Stopped by a failure; a wake that came in meanwhile (network
          // back, operator pressed "send now") tries once more.
          if (!await _send(next)) break;
        }
      } while (_drainAgain);
    } finally {
      _draining = false;
    }
  }

  QueuedLabelPrint? _firstPending(int userId) {
    for (final e in _entries) {
      if (e.status == QueuedPrintStatus.pending && e.userId == userId) return e;
    }
    return null;
  }

  /// false when sending should stop for now.
  Future<bool> _send(QueuedLabelPrint entry) async {
    entry.attempts++;
    final result = await _repository.printLabel(
      batchId: entry.batchId,
      itemId: entry.itemId,
      idempotencyKey: entry.key,
      reprint: entry.reprint,
      printedAt: entry.printedAt,
    );

    return result.fold(
      (failure) async {
        entry.lastError = failure.message;
        if (failure is UnauthorizedFailure) {
          await _changed();
          return false;
        }
        if (_isPermanent(failure)) {
          entry.status = QueuedPrintStatus.failed;
          await _changed();
          return true;
        }
        await _changed();
        _scheduleRetry(entry.attempts);
        return false;
      },
      (printed) async {
        entry
          ..status = QueuedPrintStatus.sent
          ..sentAt = _clock()
          ..lastError = null;
        _confirmations++;
        await _changed(confirmedItem: printed.item);
        return true;
      },
    );
  }

  /// A 4xx other than a timeout or rate limit will fail the same way again.
  bool _isPermanent(Failure failure) {
    final code = failure is ServerFailure ? failure.statusCode : null;
    return code != null && code >= 400 && code < 500 && code != 408 && code != 429;
  }

  void _scheduleRetry(int attempts) {
    _retryTimer?.cancel();
    final seconds = [2, 5, 10, 30, 60][(attempts - 1).clamp(0, 4)];
    _retryTimer = Timer(Duration(seconds: seconds), wake);
  }

  /// Asks the server whether the labels it answered 200 for are on record.
  /// A recorded label leaves the queue; a missing one is sent again.
  Future<void> verify() async {
    if (_verifying) return;
    final due = _entries
        .where((e) =>
            e.status == QueuedPrintStatus.sent &&
            e.sentAt != null &&
            _clock().difference(e.sentAt!) >= verifyAfter)
        .take(_verifyBatch)
        .toList();
    if (due.isEmpty || _currentUserId() == null) return;

    _verifying = true;
    try {
      final result = await _repository.verifyPrintedLabels(due.map((e) => e.key).toList());
      final recorded = result.fold((_) => null, (keys) => keys);
      if (recorded == null) return;

      var missing = false;
      for (final e in due) {
        if (recorded.contains(e.key)) {
          _entries.remove(e);
        } else {
          e
            ..status = QueuedPrintStatus.pending
            ..attempts = 0
            ..lastError = 'Serverda topilmadi, qayta yuborilmoqda';
          missing = true;
        }
      }
      await _changed();
      if (missing) wake();
    } finally {
      _verifying = false;
    }
  }

  QueuedLabelPrint? _find(String key) {
    for (final e in _entries) {
      if (e.key == key) return e;
    }
    return null;
  }

  Future<void> _changed({LabelingItemEntity? confirmedItem}) async {
    await _prefs.setString(_storageKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
    if (!_updates.isClosed) _updates.add(LabelPrintQueueUpdate(confirmedItem: confirmedItem));
  }

  void dispose() {
    _ticker?.cancel();
    _retryTimer?.cancel();
    _updates.close();
  }
}
