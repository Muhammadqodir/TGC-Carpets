import 'dart:io';

import 'win32/win32_printer.dart';

/// Discovers printers installed on the system.
///
/// Uses platform-specific methods:
///   - macOS: `lpstat -p` to list CUPS printers
///   - Windows: Win32 EnumPrintersW via dart:ffi (instant, no PowerShell)
class PrinterDiscoveryService {
  /// Cached Win32Printer instance (Windows only). Created once, reused.
  Win32Printer? _win32;

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

  /// Windows: use Win32 EnumPrintersW via dart:ffi.
  ///
  /// This is instant — no process spawning, no PowerShell, no WMI.
  /// Loads winspool.drv once and queries the spooler directly.
  Future<List<String>> _discoverWindows() async {
    try {
      _win32 ??= Win32Printer();
      return _win32!.enumPrinters();
    } catch (e) {
      return [];
    }
  }
}
