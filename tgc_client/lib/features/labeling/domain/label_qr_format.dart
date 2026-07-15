/// The QR format physically printed on every production-batch label and
/// understood by the backend scan endpoint (`P{batchId} I{itemId}`).
///
/// Single source of truth — do not build this string inline anywhere else.
/// See instructions/phase-0/11.
String buildLabelQr({required int batchId, required int itemId}) =>
    'P$batchId I$itemId';
