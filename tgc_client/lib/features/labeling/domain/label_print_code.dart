/// The small code printed vertically on the right edge of every label, e.g.
/// "S_123_04_14 15.59": which shift printed it, for which client, and when.
///
/// - shift letter: see [labelShiftLetter]
/// - client id: the client the carpet is made for, 0 for a carpet made for stock
/// - `MM_DD HH.mm`: the moment the label was printed, in the device's local time
String buildLabelPrintCode({
  required String shift,
  required int? clientId,
  required DateTime printedAt,
}) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${shift}_${clientId ?? 0}_${two(printedAt.month)}_${two(printedAt.day)} '
      '${two(printedAt.hour)}.${two(printedAt.minute)}';
}

/// Shift letter for the account printing the label.
///
/// Labels are printed from two shift accounts: "1 SMENA (YORLIQ)" prints "I",
/// "2 SMENA (YORLIQ)" prints "S". Anyone else (an admin testing a printer)
/// prints "X", so their labels are never taken for a shift's.
String labelShiftLetter(String? email) {
  switch (email?.trim().toLowerCase()) {
    case 'yorliq1@tgc-carpets.uz':
      return 'I';
    case 'yorliq2@tgc-carpets.uz':
      return 'S';
    default:
      return 'X';
  }
}
