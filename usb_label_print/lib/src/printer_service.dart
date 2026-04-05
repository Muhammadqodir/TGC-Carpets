import 'dart:io';

import 'label_config.dart';

/// Sends print jobs to system printers silently (no print dialog).
///
/// Uses platform-specific commands:
///   - macOS: `lp -d <printer> -o media=Custom.<W>x<H>mm -o fit-to-page <file>`
///   - Windows: PowerShell silent print with size configuration
class PrinterService {
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

  /// Windows: use PowerShell to print the image silently with exact sizing.
  ///
  /// Creates a temporary PowerShell script that:
  /// 1. Loads the image
  /// 2. Sets the paper size to match the label dimensions
  /// 3. Draws the image scaled to fit the label
  /// 4. Sends it to the specified printer
  Future<bool> _printWindows(
      String filePath, String printerName, LabelConfig config) async {
    try {
      // Convert mm to hundredths of an inch for .NET PrintDocument
      final widthHundredths = (config.widthMm / 25.4 * 100).round();
      final heightHundredths = (config.heightMm / 25.4 * 100).round();

      // PowerShell script to print image with exact paper size
      final psScript = '''
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Printing

\$img = [System.Drawing.Image]::FromFile("$filePath")
\$pd = New-Object System.Drawing.Printing.PrintDocument
\$pd.PrinterSettings.PrinterName = "$printerName"
\$pd.DefaultPageSettings.PaperSize = New-Object System.Drawing.Printing.PaperSize("Custom", $widthHundredths, $heightHundredths)
\$pd.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0, 0, 0, 0)

\$pd.add_PrintPage({
  param(\$sender, \$e)
  \$rect = New-Object System.Drawing.RectangleF(0, 0, \$e.PageBounds.Width, \$e.PageBounds.Height)
  \$e.Graphics.DrawImage(\$img, \$rect)
})

\$pd.Print()
\$img.Dispose()
\$pd.Dispose()
''';

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        psScript,
      ]);

      if (result.exitCode == 0) {
        return true;
      } else {
        final stderr = result.stderr as String;
        if (stderr.isNotEmpty) {
          // ignore: avoid_print
          print('Windows print error: $stderr');
        }
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}
