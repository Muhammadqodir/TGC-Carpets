import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Shows a native save-as dialog and writes [bytes] to the chosen path.
/// Returns the saved file path, or null if the user cancelled.
Future<String?> downloadExcel(Uint8List bytes, String filename) async {
  return FilePicker.saveFile(
    dialogTitle: 'Excel faylni saqlash',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
    bytes: bytes,
  );
}
