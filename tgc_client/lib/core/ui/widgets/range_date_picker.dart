import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class RangeDatePicker extends StatelessWidget {
  final DateTimeRange value;
  final ValueChanged<DateTimeRange> onChanged;

  const RangeDatePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// Returns a [DateTimeRange] spanning the current calendar month.
  static DateTimeRange get currentMonth {
    final now = DateTime.now();
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pick(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: value,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const HugeIcon(icon: HugeIcons.strokeRoundedCalendar02),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_fmt(value.start)} — ${_fmt(value.end)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDown01,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
