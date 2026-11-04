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

/// The server's answer to taking back a label printed by mistake.
class LabelUndoResult {
  const LabelUndoResult({required this.status, this.item});

  /// `undone`, `already_undone` (a resend), `not_counted` (a reprint or a
  /// print past the plan, which never counted) or `not_found` (the print
  /// never reached the server). All four mean nothing more is to be done.
  final String status;

  /// The batch line as it now stands, when the server knows the print.
  final LabelingItemEntity? item;

  static const statuses = {'undone', 'already_undone', 'not_counted', 'not_found'};
}
