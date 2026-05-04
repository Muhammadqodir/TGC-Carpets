import 'package:equatable/equatable.dart';

class ProductionAnalyticsEntity extends Equatable {
  final int totalBatches;
  final int completedBatches;
  final int inProgressBatches;
  final int plannedBatches;
  final int cancelledBatches;
  final double completionRate;
  final int productionQuantity;
  final int defectsQuantity;
  final List<DailyProductionEntity> dailyTrend;
  final List<MachineStatEntity> machineStats;

  const ProductionAnalyticsEntity({
    required this.totalBatches,
    required this.completedBatches,
    required this.inProgressBatches,
    required this.plannedBatches,
    required this.cancelledBatches,
    required this.completionRate,
    required this.productionQuantity,
    required this.defectsQuantity,
    required this.dailyTrend,
    required this.machineStats,
  });

  @override
  List<Object?> get props => [
        totalBatches,
        completedBatches,
        inProgressBatches,
        plannedBatches,
        cancelledBatches,
        completionRate,
        productionQuantity,
        defectsQuantity,
        dailyTrend,
        machineStats,
      ];
}

class DailyProductionEntity extends Equatable {
  final DateTime date;
  final int quantity;

  const DailyProductionEntity({
    required this.date,
    required this.quantity,
  });

  @override
  List<Object?> get props => [date, quantity];
}

class MachineStatEntity extends Equatable {
  final String machineName;
  final int batchCount;
  final int completedCount;

  const MachineStatEntity({
    required this.machineName,
    required this.batchCount,
    required this.completedCount,
  });

  @override
  List<Object?> get props => [machineName, batchCount, completedCount];
}
