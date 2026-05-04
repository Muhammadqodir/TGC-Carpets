import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/extensions/amount.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_bloc.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_state.dart';

class SalesAnalyticsTab extends StatelessWidget {
  const SalesAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AnalyticsBloc, AnalyticsState>(
      builder: (context, state) {
        if (state is AnalyticsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is AnalyticsError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(state.message),
              ],
            ),
          );
        }

        if (state is! SalesAnalyticsLoaded) {
          return const Center(child: Text('Ma\'lumot yuklanmoqda...'));
        }

        final data = state.data;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Jami savdo',
                      value: '${data.totalRevenue.toCurrencyString()} so\'m',
                      icon: HugeIcons.strokeRoundedDollarSquare,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Jami miqdor',
                      value: '${data.totalQuantity} ta',
                      icon: HugeIcons.strokeRoundedDatabaseExport,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Yuk chiqarishlar',
                      value: '${data.shipmentCount} ta',
                      icon: HugeIcons.strokeRoundedContainerTruck,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'O\'rtacha',
                      value: '${data.averageOrderValue.toCurrencyString()} so\'m',
                      icon: HugeIcons.strokeRoundedChartAverage,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              Text(
                'Kunlik savdo trendi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              
              if (data.dailyTrend.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Ma\'lumot mavjud emas')),
                  ),
                )
              else
                ...data.dailyTrend.map((trend) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.withOpacity(0.1),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedCalendar03,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      '${trend.date.day}.${trend.date.month}.${trend.date.year}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${trend.quantity} ta mahsulot'),
                    trailing: Text(
                      '${trend.revenue.toCurrencyString()} so\'m',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final dynamic icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(
              icon: icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
