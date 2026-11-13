/// The unique number printed as a barcode on every new carpet label: 12 digits,
/// "21", a 9-digit serial, and a check digit calculated like a UPC-A's.
///
/// Mirrors `CarpetNumberBlock` on the backend. Never change the format: these
/// numbers stay on carpets.
const String carpetNumberPrefix = '21';
const int carpetNumberMaxSerial = 999999999;

String carpetNumber(int serial) {
  if (serial < 1 || serial > carpetNumberMaxSerial) {
    throw ArgumentError.value(serial, 'serial', 'does not fit a carpet number');
  }
  final digits = '$carpetNumberPrefix${serial.toString().padLeft(9, '0')}';
  return '$digits${_checkDigit(digits)}';
}

bool isCarpetNumber(String value) =>
    RegExp(r'^21\d{10}$').hasMatch(value) &&
    _checkDigit(value.substring(0, 11)) == value.substring(11);

String _checkDigit(String elevenDigits) {
  var sum = 0;
  for (var i = 0; i < elevenDigits.length; i++) {
    sum += (elevenDigits.codeUnitAt(i) - 0x30) * (i.isEven ? 3 : 1);
  }
  return ((10 - sum % 10) % 10).toString();
}
