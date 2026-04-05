import 'dart:io';

/// Discovers printers installed on the system.
///
/// Uses platform-specific commands:
///   - macOS: `lpstat -p` to list CUPS printers
///   - Windows: `wmic printer get name` or PowerShell to list printers
class PrinterDiscoveryService {
  /// Returns a list of printer names available on the system.
  ///
  /// Returns an empty list if no printers are found or if the
  /// platform is unsupported.
  Future<List<String>> discoverPrinters() async {
    if (Platform.isMacOS) {
      return _discoverMacOS();
    } else if (Platform.isWindows) {
      return _discoverWindows();
    }
    return [];
  }

  /// macOS: parse output of `lpstat -p`
  ///
  /// Each line looks like:
  ///   printer PrinterName is idle. enabled since ...
  /// We extract the printer name from each line.
  Future<List<String>> _discoverMacOS() async {
    try {
      final result = await Process.run('lpstat', ['-p']);
      if (result.exitCode != 0) {
        return [];
      }

      final output = result.stdout as String;
      final printers = <String>[];

      for (final line in output.split('\n')) {
        final trimmed = line.trim();
        // Lines starting with "printer " contain printer names
        if (trimmed.startsWith('printer ')) {
          // Format: "printer <name> is ..."
          final parts = trimmed.split(' ');
          if (parts.length >= 2) {
            printers.add(parts[1]);
          }
        }
      }

      return printers;
    } catch (e) {
      return [];
    }
  }

  /// Windows: use .NET's InstalledPrinters via PowerShell.
  ///
  /// This is fast because it uses System.Drawing directly (no WMI/CIM overhead)
  /// and works on all Windows versions (wmic is deprecated/removed in newer builds).
  Future<List<String>> _discoverWindows() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NoLogo',
        '-NonInteractive',
        '-Command',
        'Add-Type -AssemblyName System.Drawing;'
            '[System.Drawing.Printing.PrinterSettings]::InstalledPrinters',
      ]);

      if (result.exitCode != 0) {
        return [];
      }

      final output = result.stdout as String;
      final printers = output
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      return printers;
    } catch (e) {
      return [];
    }
  }
}
