import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/carpet_number.dart';
import '../../domain/repositories/labeling_repository.dart';

/// The carpet numbers this PC holds ahead of printing.
///
/// The app prints first and tells the server afterwards, so a label cannot
/// wait for the server to give it a number. Numbers come in blocks issued in
/// advance, each kept by one PC, so two PCs never print the same one and
/// printing carries on without a network until the numbers run out.
///
/// A number is written to disk as used before its label prints. A crash or a
/// failed print can only skip a number, never use one twice.
class CarpetNumberPool {
  CarpetNumberPool({
    required LabelingRepository repository,
    required SharedPreferences prefs,
    this.topUpBelow = 250,
  })  : _repository = repository,
        _prefs = prefs {
    _load();
  }

  static const _storageKey = 'carpet_number_pool_v1';

  /// Fewer numbers than this and another block is fetched in the background.
  /// With 500 in a block, a PC holds enough for days of printing offline.
  final int topUpBelow;

  final LabelingRepository _repository;
  final SharedPreferences _prefs;

  /// Unused serials, oldest block first. Each entry is [next, last].
  final List<List<int>> _ranges = [];

  Future<void>? _fetching;

  int get remaining => _ranges.fold(0, (n, r) => n + r[1] - r[0] + 1);

  /// Fetches another block in the background if the numbers are running low.
  /// Call it when printing is about to start, and it costs nothing otherwise.
  void topUp() {
    if (remaining < topUpBelow) unawaited(_fetch());
  }

  /// The next unused number, already saved as used. Null only when this PC has
  /// none left and the server cannot be reached.
  Future<String?> take() async {
    if (_ranges.isEmpty) await _fetch();
    if (_ranges.isEmpty) return null;

    // Claimed before any await: two prints at once get different numbers.
    final range = _ranges.first;
    final serial = range[0]++;
    if (range[0] > range[1]) _ranges.removeAt(0);
    await _save();

    topUp();
    return carpetNumber(serial);
  }

  /// One request at a time, however many prints are waiting on it.
  Future<void> _fetch() => _fetching ??= _requestBlock().whenComplete(() => _fetching = null);

  Future<void> _requestBlock() async {
    final result = await _repository.requestCarpetNumberBlock();
    await result.fold(
      // The next print or page open tries again.
      (_) async {},
      (block) async {
        _ranges.add([block.firstSerial, block.lastSerial]);
        await _save();
      },
    );
  }

  void _load() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      for (final range in jsonDecode(raw) as List) {
        final pair = (range as List).cast<int>();
        if (pair.length == 2 && pair[0] <= pair[1]) _ranges.add([pair[0], pair[1]]);
      }
    } catch (_) {
      // A corrupt file must not block printing: the next block is fresh numbers.
      _ranges.clear();
    }
  }

  Future<void> _save() => _prefs.setString(_storageKey, jsonEncode(_ranges));
}
