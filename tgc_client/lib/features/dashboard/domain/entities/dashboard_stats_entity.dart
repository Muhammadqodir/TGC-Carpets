import 'package:equatable/equatable.dart';

class DashboardStatsEntity extends Equatable {
  final int productionQuantity;
  final int warehouseStock;
  final int salesQuantity;
  final double salesAmount;

  const DashboardStatsEntity({
    required this.productionQuantity,
    required this.warehouseStock,
    required this.salesQuantity,
    required this.salesAmount,
  });

  @override
  List<Object?> get props => [
        productionQuantity,
        warehouseStock,
        salesQuantity,
        salesAmount,
      ];
}
