import '../../domain/entities/dashboard_stats_entity.dart';

class DashboardStatsModel extends DashboardStatsEntity {
  const DashboardStatsModel({
    required super.productionQuantity,
    required super.warehouseStock,
    required super.salesQuantity,
    required super.salesAmount,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DashboardStatsModel(
      productionQuantity: (json['production_quantity'] as num).toInt(),
      warehouseStock: (json['warehouse_stock'] as num).toInt(),
      salesQuantity: (json['sales_quantity'] as num).toInt(),
      salesAmount: (json['sales_amount'] as num).toDouble(),
    );
  }
}
