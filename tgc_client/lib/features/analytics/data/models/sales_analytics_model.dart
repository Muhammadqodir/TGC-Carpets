import 'package:tgc_client/features/analytics/domain/entities/sales_analytics_entity.dart';

class SalesAnalyticsModel extends SalesAnalyticsEntity {
  const SalesAnalyticsModel({
    required super.totalRevenue,
    required super.totalQuantity,
    required super.shipmentCount,
    required super.averageOrderValue,
    required super.dailyTrend,
  });

  factory SalesAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return SalesAnalyticsModel(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalQuantity: (json['total_quantity'] as num?)?.toInt() ?? 0,
      shipmentCount: (json['shipment_count'] as num?)?.toInt() ?? 0,
      averageOrderValue: (json['average_order_value'] as num?)?.toDouble() ?? 0.0,
      dailyTrend: (json['daily_trend'] as List<dynamic>?)
              ?.map((e) => DailyTrendModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DailyTrendModel extends DailyTrendEntity {
  const DailyTrendModel({
    required super.date,
    required super.revenue,
    required super.quantity,
  });

  factory DailyTrendModel.fromJson(Map<String, dynamic> json) {
    return DailyTrendModel(
      date: DateTime.parse(json['date'] as String),
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}
