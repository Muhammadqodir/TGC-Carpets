import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/widgets/range_date_picker.dart';
import 'package:tgc_client/core/widgets/static_grid.dart';

class DashboardPanel extends StatelessWidget {
  const DashboardPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   "Statistika oxirgi 30 kun uchun",
          //   style: Theme.of(context).textTheme.titleMedium,
          // ),
          RangeDatePicker(),
          StaticGrid(
            columnCount: 2,
            gap: 2,
            children: [
              Expanded(
                child: _StatData(
                  title: 'Ishlab chiqarish',
                  value: '1 250ta',
                  icon: HugeIcons.strokeRoundedDatabaseAdd,
                ),
              ),
              Expanded(
                child: _StatData(
                  title: 'Omborda',
                  value: '250ta',
                  icon: HugeIcons.strokeRoundedWarehouse,
                ),
              ),
              Expanded(
                child: _StatData(
                  title: 'Savdo hajmi',
                  value: '1 568ta',
                  icon: HugeIcons.strokeRoundedDatabaseExport,
                ),
              ),
              Expanded(
                child: _StatData(
                  title: 'Savdo so\'mda',
                  value: '150M',
                  icon: HugeIcons.strokeRoundedDollarSquare,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _StatData extends StatelessWidget {
  const _StatData({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final dynamic icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
