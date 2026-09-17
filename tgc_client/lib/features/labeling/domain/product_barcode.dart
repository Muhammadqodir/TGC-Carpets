/// The product barcode printed on every label: an EAN-13, digits only.
///
/// Mirrors `ProductVariant::barcodeFor` on the backend. Some clients' systems
/// accept digits only, so this replaced "TGC-00000042". TGC has no GS1 company
/// prefix, so the number sits in GS1's in-store range (starting with 2), which
/// GS1 never gives to a manufacturer. "842" spells TGC on a phone keypad and
/// keeps our codes apart from the 2000000… numbers shop software generates.
///
/// Never change the prefix: clients keep these numbers in their own systems.
const String productBarcodePrefix = '29842';

/// EAN-13 for a variant: the prefix, the variant id in 7 digits, a check digit.
String productBarcode(int variantId) {
  if (variantId < 1 || variantId > 9999999) {
    throw ArgumentError.value(
        variantId, 'variantId', 'does not fit the 7 digits of a barcode');
  }
  final digits = '$productBarcodePrefix${variantId.toString().padLeft(7, '0')}';
  return '$digits${_ean13CheckDigit(digits)}';
}

/// Whether [value] is 13 digits with a correct EAN-13 check digit.
bool isEan13(String value) =>
    RegExp(r'^\d{13}$').hasMatch(value) &&
    _ean13CheckDigit(value.substring(0, 12)) == value.substring(12);

/// The barcode to print for a variant: the server's value when it is already
/// digits only, otherwise the one derived from [variantId]. Print history saved
/// on a device before the switch still holds "TGC-…" values, and a reprint
/// must not bring the letters back.
String labelBarcodeValue({String? stored, required int variantId}) =>
    stored != null && isEan13(stored) ? stored : productBarcode(variantId);

String _ean13CheckDigit(String twelveDigits) {
  var sum = 0;
  for (var i = 0; i < twelveDigits.length; i++) {
    sum += (twelveDigits.codeUnitAt(i) - 0x30) * (i.isEven ? 1 : 3);
  }
  return ((10 - sum % 10) % 10).toString();
}
