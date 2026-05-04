import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/extensions/amount.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_bloc.dart';
import 'package:tgc_client/features/analytics/presentation/bloc/analytics_state.dart';

class ClientAnalyticsTab extends StatelessWidget {
  const ClientAnalyticsTab({super.key});

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

        if (state is! ClientAnalyticsLoaded) {
          return const Center(child: Text('Ma\'lumot yuklanmoqda...'));
        }

        final data = state.data;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Clients by Revenue
              if (data.topClients.isNotEmpty) ...[
                Text(
                  'Top mijozlar (daromad bo\'yicha)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...data.topClients.asMap().entries.map((entry) {
                  final index = entry.key;
                  final client = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getColorForRank(index).withOpacity(0.1),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: _getColorForRank(index),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        client.shopName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${client.contactName} • ${client.region}\n'
                        '${client.shipmentCount} yuk • ${client.totalQuantity} ta',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        '${client.totalRevenue.toCurrencyString()} so\'m',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              ],
              
              const SizedBox(height: 24),
              
              // Sales by Region
              if (data.salesByRegion.isNotEmpty) ...[
                Text(
                  'Viloyatlar bo\'yicha savdo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...data.salesByRegion.map((region) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.1),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedLocation01,
                        color: Colors.blue,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      region.region,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${region.shipmentCount} yuk • ${region.totalQuantity} ta',
                    ),
                    trailing: Text(
                      '${region.totalRevenue.toCurrencyString()} so\'m',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )),
              ],
              
              const SizedBox(height: 24),
              
              // Client Order Frequency
              if (data.clientFrequency.isNotEmpty) ...[
                Text(
                  'Eng faol mijozlar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...data.clientFrequency.map((client) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.1),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedUserStar01,
                        color: Colors.orange,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      client.shopName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(client.contactName),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedShoppingBasket01,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${client.orderCount}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
  
  Color _getColorForRank(int rank) {
    switch (rank) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }
}
