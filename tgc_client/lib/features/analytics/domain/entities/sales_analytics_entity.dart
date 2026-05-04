import 'package:equatable/equatable.dart';

class SalesAnalyticsEntity extends Equatable {
  final double totalRevenue;
  final int totalQuantity;
  final int shipmentCount;
  final double averageOrderValue;
  final List<DailyTrendEntity> dailyTrend;

  const SalesAnalyticsEntity({
    required this.totalRevenue,
    required this.totalQuantity,
    required this.shipmentCount,
    required this.averageOrderValue,
    required this.dailyTrend,
  });

  @override
  List<Object?> get props => [
        totalRevenue,
        totalQuantity,
        shipmentCount,
        averageOrderValue,
        dailyTrend,
      ];
}

class DailyTrendEntity extends Equatable {
  final DateTime date;
  final double revenue;
  final int quantity;

  const DailyTrendEntity({
    required this.date,
    required this.revenue,
    required this.quantity,
  });

  @override
  List<Object?> get props => [date, revenue, quantity];
}
