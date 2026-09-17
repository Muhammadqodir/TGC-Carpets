/// The QR format physically printed on every production-batch label and
/// understood by the backend scan endpoint (`P{batchId} I{itemId}`).
///
/// Single source of truth — do not build this string inline anywhere else.
/// See instructions/phase-0/11.
String buildLabelQr({required int batchId, required int itemId}) =>
    'P$batchId I$itemId';

/// Whether [code] is a label the home-page scanner can look up, in any shape
/// that reached real carpets: `P{batch} I{item}`, `PB{batch} PBI{item}`
/// (printed 2026-05-06..14) and a `TGC-U-########` unit serial. Mirrors
/// ProductionBatchController::scanItem, so a stray QR code costs no request.
bool isProductionLabelQr(String code) => RegExp(
      r'^(TGC-U-\d{8}|P(B)?\{?\d+\}?\s+(PB)?I\{?\d+\}?)$',
      caseSensitive: false,
    ).hasMatch(code);
