import 'entities/production_operations_entity.dart';

/// One line of a per-shift breakdown: a quality, or a Kovrolin roll width.
class ShiftBreakdownLine {
  final String label;
  final int quantity;
  final double sqm;

  const ShiftBreakdownLine(this.label, this.quantity, this.sqm);
}

/// One shift's lines plus its subtotal. Shared by the page and the PDF so
/// both show the same rows in the same order.
class ShiftBreakdownGroup {
  final String shiftName;
  final List<ShiftBreakdownLine> lines;

  const ShiftBreakdownGroup(this.shiftName, this.lines);

  int get totalQuantity => lines.fold(0, (s, l) => s + l.quantity);
  double get totalSqm => lines.fold(0.0, (s, l) => s + l.sqm);
}

/// Shift output by product quality, shifts in the order of [ops.byShift]
/// (most output first), qualities by count within a shift.
List<ShiftBreakdownGroup> shiftQualityGroups(ProductionOperationsEntity ops) => _group(
      ops,
      ops.byShiftQuality.map((r) => (r.userId, ShiftBreakdownLine(r.qualityName, r.totalQuantity, r.totalSqm))),
      (a, b) => b.quantity.compareTo(a.quantity),
    );

/// Kovrolin output by roll width, narrowest first.
List<ShiftBreakdownGroup> shiftWidthGroups(ProductionOperationsEntity ops) => _group(
      ops,
      ops.byShiftWidth.map((r) => (r.userId, ShiftBreakdownLine(widthLabel(r.width), r.totalQuantity, r.totalSqm))),
      (a, b) => _widthOf(a.label).compareTo(_widthOf(b.label)),
    );

String widthLabel(int? widthCm) {
  if (widthCm == null) return 'Eni noma\'lum';
  final m = widthCm / 100;
  return '${m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toString()} m';
}

double _widthOf(String label) => double.tryParse(label.split(' ').first) ?? double.infinity;

List<ShiftBreakdownGroup> _group(
  ProductionOperationsEntity ops,
  Iterable<(int, ShiftBreakdownLine)> rows,
  int Function(ShiftBreakdownLine, ShiftBreakdownLine) compare,
) {
  final byUser = <int, List<ShiftBreakdownLine>>{};
  for (final (userId, line) in rows) {
    byUser.putIfAbsent(userId, () => []).add(line);
  }

  final order = [for (final s in ops.byShift) if (s.id != null) s.id!];
  final names = {for (final s in ops.byShift) if (s.id != null) s.id!: s.name};
  final ids = [...order.where(byUser.containsKey), ...byUser.keys.where((id) => !order.contains(id))];

  return [
    for (final id in ids)
      ShiftBreakdownGroup(names[id] ?? 'Noma\'lum', [...byUser[id]!]..sort(compare)),
  ];
}

/// Same style as AnalyticsMetric.format, without the unit: 1 234 / 1 234.5.
String formatQty(num v) => _group3(v.round().toString());

String formatSqm(num v) {
  final s = v.toStringAsFixed(1).split('.');
  return '${_group3(s[0])}.${s[1]}';
}

String _group3(String digits) {
  final neg = digits.startsWith('-');
  final d = neg ? digits.substring(1) : digits;
  final out = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) out.write(' ');
    out.write(d[i]);
  }
  return '${neg ? '-' : ''}$out';
}
