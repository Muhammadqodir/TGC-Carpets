import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Bars stacked by series (e.g. by shift), used by the analytics trend and
/// hourly charts; or, with [grouped], one bar per series side by side.
///
/// No y axis: the width goes to the bars, and each labelled bar carries
/// its value on top. Every bar is labelled when there is room; on a narrow
/// screen only the bars with an x-axis label under them, plus the tallest.
/// Hover or tap any bar for the full breakdown.
class StackedBarChart extends StatelessWidget {
  /// Short x-axis label per bar, e.g. "14.10" or "09".
  final List<String> axisLabels;

  /// Tooltip heading per bar, e.g. "14.10.2026, Se".
  final List<String> titles;

  /// Optional extra tooltip line per bar, e.g. "4 ta buyurtma".
  final List<String>? notes;

  /// Per bar: series id → value.
  final List<Map<int, double>> values;
  final List<int> series;
  final Map<int, String> names;

  /// Full value with unit for the tooltip, e.g. "12 dona" / "34.5 m²".
  final String Function(double) format;

  /// Whether small values keep one decimal on the bar tops (m²).
  final bool decimals;

  /// Side by side instead of stacked: every slot gets one bar per series,
  /// always in the same order, so the series compare at a glance. When the
  /// bars would get too thin to see, the chart scrolls sideways instead.
  final bool grouped;

  /// Where a chart that scrolls sideways starts: at the end (the latest
  /// days) or at the beginning (hour 00).
  final bool startAtEnd;

  const StackedBarChart({
    super.key,
    required this.axisLabels,
    required this.titles,
    required this.values,
    required this.series,
    required this.names,
    required this.format,
    this.decimals = false,
    this.notes,
    this.grouped = false,
    this.startAtEnd = true,
  });

  /// A single, unstacked series: no legend, no per-series tooltip lines.
  bool get _single => series.length <= 1;

  static const palette = [
    AppColors.primaryLight,
    AppColors.accent,
    Color(0xFF7B5EA7),
    Color(0xFF2196A6),
    Color(0xFFC77B3F),
  ];

  static const _height = 220.0;
  static const _bottomReserved = 22.0;
  static const _valueLabelHeight = 14.0;

  // Side by side: share of a slot the bars take, the gap between the bars
  // of one slot, and the thinnest bar before the chart scrolls instead.
  static const _groupFill = 0.84;
  static const _barGap = 1.0;
  static const _minBar = 3.5;
  static const _maxBar = 22.0;

  /// Accounts in display order: "1 SMENA" before "2 SMENA", so a shift
  /// keeps its colour across periods and across charts.
  static List<int> seriesOf(Iterable<int> userIds, Map<int, String> names) =>
      userIds.toSet().toList()..sort((a, b) => (names[a] ?? '').compareTo(names[b] ?? ''));

  static Map<int, Color> colorsOf(List<int> series) => {
        for (var i = 0; i < series.length; i++) series[i]: palette[i % palette.length],
      };

  /// Colour key for the shift series.
  static Widget legend(List<int> series, Map<int, String> names) {
    final colorOf = colorsOf(series);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final id in series)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colorOf[id],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    names[id] ?? 'Noma\'lum',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = values.length;
    final colorOf = colorsOf(series);
    final side = grouped && !_single;
    final k = side ? series.length : 1;
    final totals = [for (final v in values) v.values.fold<double>(0, (s, x) => s + x)];

    // How high every bar goes: the stack's total, or each series' own value.
    final tops = [
      for (var i = 0; i < n; i++)
        side ? [for (final id in series) values[i][id] ?? 0.0] : [totals[i]],
    ];
    var peak = 0.0;
    var tallest = (-1, -1);
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < k; j++) {
        if (tops[i][j] > peak) {
          peak = tops[i][j];
          tallest = (i, j);
        }
      }
    }
    final maxY = peak > 0 ? peak : 1.0;
    final longestValue = tops.fold<int>(
      0,
      (m, b) => b.fold(m, (m2, v) => v > 0 && _compact(v).length > m2 ? _compact(v).length : m2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_single) legend(series, names),
        LayoutBuilder(
          builder: (context, c) {
            final minSlot = side ? (k * _minBar + (k - 1) * _barGap) / _groupFill : 0.0;
            final w = math.max(c.maxWidth, n * minSlot);
            final slot = w / n;
            final barWidth = side
                ? ((slot * _groupFill - (k - 1) * _barGap) / k).clamp(_minBar, _maxBar)
                : (slot * 0.7).clamp(3.0, 28.0);
            final groupWidth = k * barWidth + (k - 1) * _barGap;
            // With spaceAround, slot i is centred at (i + 0.5) / n of the
            // width, its bars laid out left to right from there.
            double centreOf(int i, int j) =>
                (i + 0.5) * slot - groupWidth / 2 + j * (barWidth + _barGap) + barWidth / 2;

            // Room for an axis label ("09" vs "14.10") and for a value on
            // top; values only go on bars that also have an axis label.
            final longest = axisLabels.fold<int>(0, (m, l) => l.length > m ? l.length : m);
            final every = ((longest * 5.5 + 6) / slot).ceil().clamp(1, n);
            final valueEvery = every * ((26 / slot).ceil() / every).ceil();
            final plotH = _height - _bottomReserved - _valueLabelHeight;
            // Side by side, a value fits over each bar only when the bars
            // are wide; otherwise just the tallest bar carries one.
            final perBar = !side || barWidth + _barGap >= longestValue * 5.5 + 2;

            bool labelled(int i, int j) =>
                tops[i][j] > 0 && ((i, j) == tallest || (perBar && i % valueEvery == 0));

            final chart = SizedBox(
              width: w,
              height: _height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: _valueLabelHeight,
                    child: BarChart(
                      BarChartData(
                        maxY: maxY,
                        minY: 0,
                        alignment: BarChartAlignment.spaceAround,
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(
                          show: true,
                          border: const Border(bottom: BorderSide(color: AppColors.divider)),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: _bottomReserved,
                              getTitlesWidget: (v, _) {
                                final i = v.toInt();
                                if (i < 0 || i >= n || i % every != 0) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    axisLabels[i],
                                    style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: [
                          for (var i = 0; i < n; i++)
                            BarChartGroupData(
                              x: i,
                              barsSpace: _barGap,
                              barRods: side
                                  ? [
                                      for (var j = 0; j < k; j++)
                                        BarChartRodData(
                                          toY: tops[i][j],
                                          width: barWidth,
                                          color: colorOf[series[j]],
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(barWidth >= 8 ? 3 : 1.5),
                                          ),
                                          // Not drawn: it makes the whole column
                                          // tappable, not just a short bar.
                                          backDrawRodData: BackgroundBarChartRodData(toY: maxY),
                                        ),
                                    ]
                                  : [
                                      BarChartRodData(
                                        toY: totals[i],
                                        width: barWidth,
                                        color: Colors.transparent,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                        rodStackItems: _stack(values[i], colorOf),
                                      ),
                                    ],
                            ),
                        ],
                        barTouchData: BarTouchData(
                          allowTouchBarBackDraw: side,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => AppColors.textPrimary.withAlpha(235),
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            maxContentWidth: 280,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            getTooltipItem: (group, _, __, ___) =>
                                _tooltip(group.x, totals[group.x], colorOf),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Values above the labelled bars.
                  for (var i = 0; i < n; i++)
                    for (var j = 0; j < k; j++)
                      if (labelled(i, j))
                        Positioned(
                          left: centreOf(i, j) - 30,
                          width: 60,
                          top: plotH * (1 - tops[i][j] / maxY),
                          child: IgnorePointer(
                            child: Text(
                              _compact(tops[i][j]),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: (i, j) == tallest ? FontWeight.w800 : FontWeight.w600,
                                color: (i, j) == tallest ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            );

            return w > c.maxWidth ? _SideScroll(startAtEnd: startAtEnd, child: chart) : chart;
          },
        ),
      ],
    );
  }

  List<BarChartRodStackItem> _stack(Map<int, double> v, Map<int, Color> colorOf) {
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    for (final id in series) {
      final val = v[id] ?? 0;
      if (val <= 0) continue;
      items.add(BarChartRodStackItem(from, from + val, colorOf[id]!));
      from += val;
    }
    return items;
  }

  BarTooltipItem _tooltip(int i, double total, Map<int, Color> colorOf) {
    final v = values[i];
    final note = notes?[i];
    return BarTooltipItem(
      '${titles[i]}\n',
      const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      textAlign: TextAlign.left,
      children: [
        for (final id in series)
          if (!_single && (v[id] ?? 0) > 0)
            TextSpan(
              text: '${names[id] ?? 'Noma\'lum'}: ',
              style: TextStyle(
                color: Color.lerp(colorOf[id], Colors.white, 0.35),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              children: [
                TextSpan(
                  text: '${format(v[id]!)}\n',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w400, fontSize: 12),
                ),
              ],
            ),
        TextSpan(
          text: _single ? format(total) : 'Jami: ${format(total)}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
        ),
        if (note != null && note.isNotEmpty)
          TextSpan(
            text: '\n$note',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w400, fontSize: 12),
          ),
      ],
    );
  }

  /// Bar-top number without the unit: "128", "1.2k", "45.5".
  String _compact(double v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (decimals && v < 100) return v.toStringAsFixed(1);
    return v.round().toString();
  }
}

/// A chart wider than the screen, scrolled sideways with a visible thumb
/// so it is clear there is more.
class _SideScroll extends StatefulWidget {
  final bool startAtEnd;
  final Widget child;

  const _SideScroll({required this.startAtEnd, required this.child});

  @override
  State<_SideScroll> createState() => _SideScrollState();
}

class _SideScrollState extends State<_SideScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        // Reversed, the view opens on the right-hand end.
        reverse: widget.startAtEnd,
        padding: const EdgeInsets.only(bottom: 8),
        child: widget.child,
      ),
    );
  }
}

/// Labels for trend buckets as the analytics APIs send them:
/// day "2026-10-14", week "2026-43", month "2026-10".
class TrendLabels {
  TrendLabels._();

  static const _weekdays = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  /// Every day from [from] to [to] for a daily chart, so a day with
  /// nothing shows as a gap instead of disappearing. Empty otherwise.
  static List<String> allDays(String trendBy, String from, String to) {
    if (trendBy != 'day') return const [];
    final f = DateTime.tryParse(from);
    final t = DateTime.tryParse(to);
    if (f == null || t == null) return const [];
    return [
      for (var d = f; !d.isAfter(t); d = DateTime(d.year, d.month, d.day + 1))
        '${d.year}-${_two(d.month)}-${_two(d.day)}',
    ];
  }

  /// Axis label: "14.10", "43-h", "10.26".
  static String short(String raw, String trendBy) {
    if (trendBy == 'day' && raw.length == 10) {
      return '${raw.substring(8)}.${raw.substring(5, 7)}';
    }
    if (trendBy == 'week') return '${raw.split('-').last}-h';
    if (trendBy == 'month' && raw.length == 7) {
      return '${raw.substring(5)}.${raw.substring(2, 4)}';
    }
    return raw;
  }

  /// Tooltip heading: "14.10.2026, Se", "2026, 43-hafta", "10.2026".
  static String long(String raw, String trendBy) {
    if (trendBy == 'day') {
      final d = DateTime.tryParse(raw);
      if (d != null) {
        return '${_two(d.day)}.${_two(d.month)}.${d.year}, ${_weekdays[d.weekday - 1]}';
      }
    }
    if (trendBy == 'week') {
      final p = raw.split('-');
      if (p.length == 2) return '${p[0]}, ${p[1]}-hafta';
    }
    if (trendBy == 'month' && raw.length == 7) {
      return '${raw.substring(5)}.${raw.substring(0, 4)}';
    }
    return raw;
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
