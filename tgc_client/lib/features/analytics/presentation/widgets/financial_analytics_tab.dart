import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/extensions/amount.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_bloc.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_state.dart';

class FinancialAnalyticsTab extends StatelessWidget {
  const FinancialAnalyticsTab({super.key});

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

        if (state is! FinancialAnalyticsLoaded) {
          return const Center(child: Text('Ma\'lumot yuklanmoqda...'));
        }

        final data = state.data;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Financial Summary
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedDollarCircle,
                            color: Colors.green,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jami daromad',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  '${data.totalRevenue.toCurrencyString()} so\'m',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                              color: Colors.blue,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${data.totalPayments.toCurrencyString()} so\'m',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'To\'lovlar',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedAlert01,
                              color: Colors.red,
                              size: 28,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${data.outstandingDebt.toCurrencyString()} so\'m',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Qarz',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              if (data.topDebtors.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Eng ko\'p qarzdorlar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...data.topDebtors.map((debtor) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedUser,
                        color: Colors.red,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      debtor.shopName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${debtor.contactName} • ${debtor.region}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${debtor.debt.toCurrencyString()} so\'m',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Savdo: ${debtor.totalSales.toCurrencyShort()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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
