/// Configuration for label dimensions and print settings.
///
/// Defines the physical label size in millimeters and the printer DPI
/// to calculate exact pixel dimensions for the output PNG.
class LabelConfig {
  /// Label width in millimeters.
  final double widthMm;

  /// Label height in millimeters.
  final double heightMm;

  /// Printer resolution in dots per inch (default: 203 for thermal printers).
  final int dpi;

  const LabelConfig({
    this.widthMm = 58,
    this.heightMm = 40,
    this.dpi = 203,
  });

  /// Exact pixel width for the PNG output: widthMm / 25.4 * dpi
  int get widthPx => (widthMm / 25.4 * dpi).round();

  /// Exact pixel height for the PNG output: heightMm / 25.4 * dpi
  int get heightPx => (heightMm / 25.4 * dpi).round();

  /// Common preset: 58mm x 40mm at 203 DPI
  static const preset58x40 = LabelConfig(widthMm: 58, heightMm: 40);

  /// Common preset: 58mm x 30mm at 203 DPI
  static const preset58x30 = LabelConfig(widthMm: 58, heightMm: 30);

  /// Common preset: 40mm x 30mm at 203 DPI
  static const preset40x30 = LabelConfig(widthMm: 40, heightMm: 30);

  /// Common preset: 80mm x 50mm at 203 DPI
  static const preset80x50 = LabelConfig(widthMm: 80, heightMm: 50);

  /// Common preset: 60mm x 60mm at 203 DPI
  static const preset60x60 = LabelConfig(widthMm: 58, heightMm: 60);

  @override
  String toString() =>
      'LabelConfig(${widthMm}x${heightMm}mm @ ${dpi}dpi = ${widthPx}x${heightPx}px)';
}
