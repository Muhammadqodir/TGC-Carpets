/// A simple Flutter package for silent label printing on macOS and Windows.
/// Package: usb_label_print
///
/// This package provides:
/// - [LabelConfig]: Configuration for label size (mm) and DPI.
/// - [LabelWidget]: A fixed-size container — pass any widget as [child] to design your label.
/// - [LabelRenderer]: Captures the label widget as a PNG image.
/// - [PrinterDiscoveryService]: Detects system-installed printers.
/// - [PrinterService]: Prints files silently using system commands (no print dialog).
library;

export 'src/label_config.dart';
export 'src/label_widget.dart';
export 'src/label_renderer.dart';
export 'src/printer_discovery_service.dart';
export 'src/printer_service.dart';
