import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Shows a native save-as dialog and writes [bytes] to the chosen path.
/// file_picker's saveFile already writes the bytes via FilePickerUtils.saveBytesToFile.
/// Returns the saved file path, or null if the user cancelled.
Future<String?> downloadPdf(Uint8List bytes, String filename) async {
  return FilePicker.saveFile(
    dialogTitle: 'PDF ni saqlash',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    bytes: bytes,
  );
}
