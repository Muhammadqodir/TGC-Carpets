import 'labeling_item_entity.dart';

/// The server's answer to one print-label call.
class LabelPrintResult {
  const LabelPrintResult({required this.item, required this.counted});

  /// The batch line as the server has it after this print.
  final LabelingItemEntity item;

  /// false when the server recorded the label as a reprint or a print past
  /// the plan instead of counting a carpet.
  final bool counted;
}
