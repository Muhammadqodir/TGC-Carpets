import 'package:flutter/material.dart';

import 'label_config.dart';

/// A fixed-size container for thermal label printing.
///
/// Set the physical dimensions via [config], then place any Flutter widget
/// inside [child] to design the label however you want.
///
/// ```dart
/// LabelWidget(
///   config: LabelConfig.preset58x40,
///   child: Row(
///     children: [
///       QrImageView(data: 'https://example.com', size: 200),
///       SizedBox(width: 8),
///       Expanded(child: Text('Product Name')),
///     ],
///   ),
/// )
/// ```
///
/// Uses [LabelConfig] to set exact pixel dimensions from physical size (mm)
/// and printer DPI.
class LabelWidget extends StatelessWidget {
  /// Label configuration (size in mm + DPI). Determines pixel dimensions.
  final LabelConfig config;

  /// Background color of the label.
  final Color backgroundColor;

  /// Padding inside the label container.
  final EdgeInsets padding;

  /// The label content. You control the entire layout.
  final Widget child;

  const LabelWidget({
    super.key,
    required this.child,
    this.config = LabelConfig.preset58x40,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: config.widthPx.toDouble(),
      height: config.heightPx.toDouble(),
      color: backgroundColor,
      padding: padding,
      child: child,
    );
  }
}
