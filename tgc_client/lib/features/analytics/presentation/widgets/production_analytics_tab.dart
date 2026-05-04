import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_bloc.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_state.dart';

class ProductionAnalyticsTab extends StatelessWidget {
  const ProductionAnalyticsTab({super.key});

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

        if (state is! ProductionAnalyticsLoaded) {
          return const Center(child: Text('Ma\'lumot yuklanmoqda...'));
        }

        final data = state.data;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Batch Statistics
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Jami partiyalar',
                      value: '${data.totalBatches}',
                      icon: HugeIcons.strokeRoundedPackage,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Bajarilgan',
                      value: '${data.completedBatches}',
                      icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Jarayonda',
                      value: '${data.inProgressBatches}',
                      icon: HugeIcons.strokeRoundedLoading03,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Bajarilish %',
                      value: '${data.completionRate.toStringAsFixed(1)}%',
                      icon: HugeIcons.strokeRoundedAnalytics02,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ishlab chiqarildi',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${data.productionQuantity} ta',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Nuqsonli',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '${data.defectsQuantity} ta',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              if (data.machineStats.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Dastgoh statistikasi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...data.machineStats.map((machine) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedSetup01,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      machine.machineName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('Bajarilgan: ${machine.completedCount}'),
                    trailing: Text(
                      '${machine.batchCount}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final dynamic icon;
  final Color color;

  const _StatCard({
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
