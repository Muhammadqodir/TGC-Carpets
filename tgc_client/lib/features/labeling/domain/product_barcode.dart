/// The product barcode number on every label: 8 digits, drawn as a plain
/// Code 128.
///
/// Mirrors `ProductVariant::barcodeFor` on the backend: "5", the variant id in
/// 6 digits, an EAN-8 check digit ("50059843" for variant 5984). Since
/// November 2026; half as wide as the 13 digits before it, so a PDA aimed at
/// the label's 21 carpet number does not catch it instead. TGC has no GS1
/// prefix (the user's choice), and the user accepted that a shop system could
/// in theory hold a foreign product with the same 8 digits.
///
/// Never change it again: clients keep these numbers in their own systems.
const String productBarcodePrefix = '5';

/// The 13-digit barcode printed from September to November 2026 ("29842" +
/// 7-digit id + check). Still on carpets and in clients' systems.
const String legacyProductBarcodePrefix = '29842';

/// EAN-8 for a variant: the prefix, the variant id in 6 digits, a check digit.
String productBarcode(int variantId) {
  if (variantId < 1 || variantId > 999999) {
    throw ArgumentError.value(
        variantId, 'variantId', 'does not fit the 6 digits of a barcode');
  }
  final digits = '$productBarcodePrefix${variantId.toString().padLeft(6, '0')}';
  return '$digits${_eanCheckDigit(digits)}';
}

/// Whether [value] is 13 digits with a correct EAN-13 check digit.
bool isEan13(String value) =>
    RegExp(r'^\d{13}$').hasMatch(value) && _hasValidCheckDigit(value);

/// Whether [value] is 8 digits with a correct EAN-8 check digit.
bool isEan8(String value) =>
    RegExp(r'^\d{8}$').hasMatch(value) && _hasValidCheckDigit(value);

/// Whether [value] is a TGC product barcode, current or the 13-digit one
/// before it. Names a product, never one carpet.
bool isProductBarcode(String value) =>
    (value.startsWith(productBarcodePrefix) && isEan8(value)) ||
    (value.startsWith(legacyProductBarcodePrefix) && isEan13(value));

/// The barcode to print for a variant: the server's value when it is already
/// the current 8 digits, otherwise the one derived from [variantId]. Print
/// history saved on a device before the switch still holds 13-digit or
/// "TGC-…" values, and a reprint must not bring them back.
String labelBarcodeValue({String? stored, required int variantId}) =>
    stored != null && stored.startsWith(productBarcodePrefix) && isEan8(stored)
        ? stored
        : productBarcode(variantId);

bool _hasValidCheckDigit(String digits) =>
    _eanCheckDigit(digits.substring(0, digits.length - 1)) ==
    digits.substring(digits.length - 1);

/// EAN/UPC check digit: weights 3 and 1 alternating from the rightmost data
/// digit, so it serves EAN-8 and EAN-13 alike.
String _eanCheckDigit(String data) {
  var sum = 0;
  for (var i = 0; i < data.length; i++) {
    final fromRight = data.length - 1 - i;
    sum += (data.codeUnitAt(i) - 0x30) * (fromRight.isEven ? 3 : 1);
  }
  return ((10 - sum % 10) % 10).toString();
}
