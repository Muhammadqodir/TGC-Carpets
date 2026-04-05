# usb_label_print

A Flutter package for printing labels silently on **macOS** and **Windows** — no print dialog, no PDF, no raw printer commands.

Supports any label size (58×40mm, 80×50mm, custom) and any layout you can build with Flutter widgets.

## Features

- **Silent printing** — no system print dialog
- **Printer discovery** — list installed printers instantly
- **Configurable labels** — design any label layout using Flutter widgets
- **Exact sizing** — mm-to-pixel conversion at your printer's DPI
- **Fast** — Win32 FFI on Windows (no PowerShell), `lp` on macOS

| Platform | Discovery | Printing |
|----------|-----------|----------|
| macOS | `lpstat -p` | `lp` with CUPS media options |
| Windows | `EnumPrintersW` (winspool.drv) | GDI+ via printer driver (gdiplus.dll) |

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  usb_label_print:
    path: ../usb_label_print  # local path
```

Then run:

```bash
flutter pub get
```

### Platform Setup

#### macOS

Disable the App Sandbox so the package can access printers and run `lp`:

In both `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.app-sandbox</key>
<false/>
<key>com.apple.security.print</key>
<true/>
```

#### Windows

No extra setup needed. The package uses Win32 FFI directly.

## Quick Start

```dart
import 'package:usb_label_print/usb_label_print.dart';
import 'package:qr_flutter/qr_flutter.dart';

// 1. Create a label widget (wrap in RepaintBoundary with a GlobalKey)
final labelKey = GlobalKey();

RepaintBoundary(
  key: labelKey,
  child: LabelWidget(
    config: LabelConfig.preset58x40,
    child: Row(
      children: [
        QrImageView(data: 'https://example.com/sku001', size: 200),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Product SKU-001\nPrice: \$29.99'),
        ),
      ],
    ),
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
await printer.printFile(
  filePath: pngPath!,
  printerName: printers.first,
  config: LabelConfig.preset58x40,
);
```

## API Reference

### LabelConfig

Defines label size in millimeters and printer DPI. Calculates exact pixel dimensions.

```dart
// Use a preset
LabelConfig.preset58x40   // 58mm × 40mm @ 203 DPI → 463 × 320 px
LabelConfig.preset58x30   // 58mm × 30mm @ 203 DPI → 463 × 240 px
LabelConfig.preset40x30   // 40mm × 30mm @ 203 DPI → 320 × 240 px
LabelConfig.preset80x50   // 80mm × 50mm @ 203 DPI → 639 × 400 px

// Or define a custom size
const config = LabelConfig(widthMm: 100, heightMm: 60, dpi: 300);
```

### LabelWidget

A fixed-size container with exact pixel dimensions from `LabelConfig`. Pass any Flutter widget as `child` to design the label however you want.

```dart
LabelWidget(
  config: LabelConfig.preset58x40,
  // optional:
  backgroundColor: Colors.white,
  padding: EdgeInsets.all(8),
  // required:
  child: Row(
    children: [
      QrImageView(data: 'https://example.com', size: 200),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset('assets/logo.png', height: 36),
            const SizedBox(height: 4),
            const Text(
              'Product Name\nSKU: CP-001',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ],
  ),
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `child` | `Widget` | required | Your label layout |
| `config` | `LabelConfig` | `preset58x40` | Physical dimensions + DPI |
| `backgroundColor` | `Color` | `Colors.white` | Label background |
| `padding` | `EdgeInsets` | `EdgeInsets.all(8)` | Inner padding |

### LabelRenderer

Captures any widget wrapped in `RepaintBoundary` as a PNG file.

```dart
final labelKey = GlobalKey();

// Wrap your label
RepaintBoundary(
  key: labelKey,
  child: LabelWidget(...),
);

// Render to PNG (returns temp file path)
final renderer = LabelRenderer(labelKey);
final path = await renderer.renderToPng(pixelRatio: 1.0);
```

`pixelRatio: 1.0` produces pixels matching the `LabelConfig` dimensions exactly. Higher values produce larger PNGs that get scaled down during printing.

### PrinterDiscoveryService

```dart
final discovery = PrinterDiscoveryService();
final printers = await discovery.discoverPrinters();
// Returns: ['Xprinter_XP-365B', 'HP_LaserJet', ...]
```

### PrinterService

```dart
final printer = PrinterService();
final success = await printer.printFile(
  filePath: '/path/to/label.png',
  printerName: 'Xprinter_XP-365B',
  config: LabelConfig.preset58x40,  // tells macOS the media size
);
```

## Architecture

```
lib/
  usb_label_print.dart           # Barrel exports
  src/
    label_config.dart            # Size (mm) + DPI → pixel dimensions
    label_widget.dart            # Fixed-size container — pass any widget as child
    label_renderer.dart          # Widget → PNG via RepaintBoundary
    printer_discovery_service.dart  # Detect system printers
    printer_service.dart         # Silent print (macOS: lp, Windows: GDI+)
    win32/
      win32_printer.dart         # Win32 FFI: EnumPrintersW + GDI+ printing
```

## Example

A full runnable example is in `example/` with live label preview, label size picker, printer selection, and one-click printing.

```bash
cd example
flutter run -d macos   # or -d windows
```

## Requirements

- Flutter 3.10+
- macOS or Windows
- At least one system printer installed
