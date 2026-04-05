# usb_label_print

A simple Flutter package for printing 58mm x 40mm labels silently on **macOS** and **Windows** — no print dialog, no PDF, no raw printer protocols.

## How it works

1. Build a label using `LabelWidget` (text + QR code + optional logo)
2. Capture the widget as a PNG with `LabelRenderer`
3. Discover system printers with `PrinterDiscoveryService`
4. Print silently with `PrinterService` via system commands

### Platform commands

| Platform | Discovery         | Printing                          |
|----------|-------------------|-----------------------------------|
| macOS    | `lpstat -p`       | `lp -d <printer> <file>`         |
| Windows  | `Get-Printer`     | `Start-Process -Verb PrintTo`     |

## Architecture

```
lib/src/
  label_widget.dart              # Fixed-size label with text, QR, logo
  label_renderer.dart            # Widget → PNG via RepaintBoundary
  printer_discovery_service.dart # Detect system printers
  printer_service.dart           # Silent print via system commands
```

## Usage

```dart
import 'package:usb_label_print/usb_label_print.dart';

// 1. Create the label widget (wrap in RepaintBoundary with a GlobalKey)
final labelKey = GlobalKey();

RepaintBoundary(
  key: labelKey,
  child: LabelWidget(
    text: 'Product SKU-001',
    qrData: 'https://example.com/sku001',
  ),
);

// 2. Render to PNG
final renderer = LabelRenderer(labelKey);
final pngPath = await renderer.renderToPng();

// 3. Discover printers
final discovery = PrinterDiscoveryService();
final printers = await discovery.discoverPrinters();

// 4. Print silently
final printer = PrinterService();
final success = await printer.printFile(
  filePath: pngPath!,
  printerName: printers.first,
);
```

## Example

A full runnable example is in `example/`. To run:

```bash
cd example
flutter run -d macos   # or -d windows
```

## Requirements

- Flutter 3.10+
- macOS or Windows
- At least one system printer installed
