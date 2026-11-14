import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The built-in barcode imager of a Zebra PDA (TC15), driven through
/// DataWedge by MainActivity.kt.
///
/// On every other device [isAvailable] is false and [scans] never emits, so
/// pages can listen unconditionally and fall back to the camera.
class HardwareScanner {
  HardwareScanner._();
  static final HardwareScanner instance = HardwareScanner._();

  static const _methods = MethodChannel('uz.mq.tgc/scanner');
  static const _events = EventChannel('uz.mq.tgc/scanner/events');

  bool? _available;
  Stream<String>? _scans;

  /// True on a device with DataWedge (a Zebra PDA). Cached after the first
  /// call; false on iOS, desktop and web.
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    if (kIsWeb || !Platform.isAndroid) return _available = false;
    try {
      _available = await _methods.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      _available = false;
    }
    return _available!;
  }

  /// Each decoded barcode's text. The native receiver is registered only
  /// while something listens, so a scan on a page that does not listen is
  /// dropped rather than queued.
  Stream<String> get scans {
    if (kIsWeb || !Platform.isAndroid) return const Stream.empty();
    return _scans ??= _events
        .receiveBroadcastStream()
        .map((event) => event is Map ? event['data'] as String? : null)
        .where((data) => data != null && data.isNotEmpty)
        .cast<String>();
  }

  /// Fires the imager as if the trigger button were pressed.
  Future<void> softTrigger() async {
    if (!(await isAvailable())) return;
    try {
      await _methods.invokeMethod<void>('softTrigger');
    } catch (_) {}
  }
}
