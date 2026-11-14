import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Receives one decoded barcode.
typedef HardwareScanHandler = void Function(String code);

/// The built-in barcode imager of a Zebra PDA (TC15), driven through
/// DataWedge by MainActivity.kt.
///
/// Scans go to whoever claimed the scanner last ([claim]) — the shipment
/// page while it is open, the product page while it is showing — and
/// otherwise to the app-wide fallback set by [start], which opens the
/// product screen. On every other device [isAvailable] is false and nothing
/// is ever delivered, so callers need no platform checks.
class HardwareScanner {
  HardwareScanner._();
  static final HardwareScanner instance = HardwareScanner._();

  static const _methods = MethodChannel('uz.mq.tgc/scanner');
  static const _events = EventChannel('uz.mq.tgc/scanner/events');

  bool? _available;
  StreamSubscription<dynamic>? _sub;
  HardwareScanHandler? _fallback;
  final List<HardwareScanHandler> _claims = [];

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

  /// Starts listening for the whole app; [fallback] gets every scan nobody
  /// has claimed.
  Future<void> start(HardwareScanHandler fallback) async {
    _fallback = fallback;
    if (_sub != null || !await isAvailable()) return;
    _sub = _events.receiveBroadcastStream().listen((event) {
      final data = event is Map ? event['data'] : null;
      if (data is! String || data.isEmpty) return;
      final handler = _claims.isNotEmpty ? _claims.last : _fallback;
      handler?.call(data);
    });
  }

  /// Takes the scanner until the returned callback is called. Claims stack:
  /// the latest one wins, and releasing it hands scans back to the one
  /// before.
  VoidCallback claim(HardwareScanHandler handler) {
    _claims.add(handler);
    return () => _claims.remove(handler);
  }

  /// Fires the imager as if the trigger button were pressed.
  Future<void> softTrigger() async {
    if (!(await isAvailable())) return;
    try {
      await _methods.invokeMethod<void>('softTrigger');
    } catch (_) {}
  }
}
