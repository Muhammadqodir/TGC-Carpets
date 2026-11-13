/// A run of carpet number serials the server issued to this PC.
class CarpetNumberBlock {
  const CarpetNumberBlock({required this.firstSerial, required this.lastSerial});

  final int firstSerial;
  final int lastSerial;
}
