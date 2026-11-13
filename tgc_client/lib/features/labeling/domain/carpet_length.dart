// The real length of a Kovrolin roll, typed in metres before its label
// prints and sent to the server in whole centimetres.

/// How far a real length may be from the size's nominal length. Rolls come
/// out 1 to 5 m off; past this it is a typo, not a roll.
const carpetLengthMaxDeviationCm = 1000;

/// [text] in metres ("28.7", "28,75", "29") as whole centimetres, or null
/// when it is not a positive number with at most two decimals.
int? parseCarpetLengthMetres(String text) {
  final normalized = text.trim().replaceAll(',', '.');
  final match = RegExp(r'^(\d{1,4})(?:\.(\d{1,2}))?$').firstMatch(normalized);
  if (match == null) return null;

  final metres = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(2, '0');
  final cm = metres * 100 + int.parse(fraction);
  return cm > 0 ? cm : null;
}

/// Why [cm] cannot be printed for a size of [nominalCm], or null when it can.
String? carpetLengthError(int? cm, int? nominalCm) {
  if (cm == null) return 'Uzunlikni metrda kiriting, masalan 28.7';
  if (nominalCm != null && (cm - nominalCm).abs() > carpetLengthMaxDeviationCm) {
    return 'Uzunlik ${formatCarpetLengthMetres(nominalCm)} m dan '
        '${carpetLengthMaxDeviationCm ~/ 100} m dan ortiq farq qilmasligi kerak';
  }
  return null;
}

/// [cm] as metres the way a worker reads it: "28.7", "30", "28.75".
String formatCarpetLengthMetres(int cm) {
  final metres = cm ~/ 100;
  final rest = cm % 100;
  if (rest == 0) return '$metres';
  if (rest % 10 == 0) return '$metres.${rest ~/ 10}';
  return '$metres.${rest.toString().padLeft(2, '0')}';
}
