import 'dart:io';

import 'label_config.dart';
import 'win32/win32_printer.dart';

/// Sends print jobs to system printers silently (no print dialog).
///
/// Uses platform-specific methods:
///   - macOS: `lp -d <printer> -o media=Custom.<W>x<H>mm -o fit-to-page <file>`
///   - Windows: GDI+ rendering through the printer driver via dart:ffi
class PrinterService {
  /// Cached Win32Printer instance (Windows only). Created once, reused.
  Win32Printer? _win32;
  /// Prints a file silently to the specified printer.
  ///
  /// [filePath] is the absolute path to the PNG file to print.
  /// [printerName] is the system name of the target printer.
  /// [config] defines the label size so the printer uses the correct media.
  ///
  /// Returns `true` if the print command executed successfully,
  /// `false` otherwise.
  Future<bool> printFile({
    required String filePath,
    required String printerName,
    LabelConfig config = LabelConfig.preset58x40,
  }) async {
    // Validate the file exists
    final file = File(filePath);
    if (!await file.exists()) {
      return false;
    }

    if (Platform.isMacOS) {
      return _printMacOS(filePath, printerName, config);
    } else if (Platform.isWindows) {
      return _printWindows(filePath, printerName, config);
    }

    return false;
  }

  /// macOS: use the `lp` command to send the file to a CUPS printer.
  ///
  /// `lp -d <printer> -o media=Custom.<W>x<H>mm -o fit-to-page <file>`
  ///   -d: destination printer
  ///   -o media: set custom paper size matching the label
  ///   -o fit-to-page: scale image to fit the label exactly
  ///   -o orientation-requested=3: portrait (feed direction)
  ///
  /// This prints silently without any dialog.
  Future<bool> _printMacOS(
      String filePath, String printerName, LabelConfig config) async {
    try {
      // Build the custom media size string: "Custom.58x40mm"
      final mediaSize =
          'Custom.${config.widthMm.toStringAsFixed(0)}x${config.heightMm.toStringAsFixed(0)}mm';

      final result = await Process.run('lp', [
        '-d', printerName, // destination printer
        '-o', 'media=$mediaSize', // exact label size
        '-o', 'fit-to-page', // scale image to fit label
        '-o', 'orientation-requested=3', // portrait orientation
        filePath, // file to print
      ]);

      if (result.exitCode == 0) {
        return true;
      } else {
        final stderr = result.stderr as String;
        if (stderr.isNotEmpty) {
          // ignore: avoid_print
          print('macOS print error: $stderr');
        }
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Windows: print image via GDI+ through the printer driver.
  ///
  /// Uses CreateDCW → GdipDrawImageRectI → EndDoc via dart:ffi.
  /// This renders the image through the printer driver, which converts it
  /// to the printer's native format. Works with all printers that have a
  /// Windows driver installed. No PowerShell, no process spawning.
  Future<bool> _printWindows(
      String filePath, String printerName, LabelConfig config) async {
    try {
      _win32 ??= Win32Printer();

      return _win32!.printImage(
        printerName: printerName,
        filePath: filePath,
        docName: 'Label ${config.widthMm.toStringAsFixed(0)}x${config.heightMm.toStringAsFixed(0)}mm',
      );
    } catch (e) {
      // ignore: avoid_print
      print('Windows print error: $e');
      return false;
    }
  }
}
