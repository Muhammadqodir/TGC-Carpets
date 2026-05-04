import 'package:tgc_client/features/analytics/domain/entities/production_analytics_entity.dart';

class ProductionAnalyticsModel extends ProductionAnalyticsEntity {
  const ProductionAnalyticsModel({
    required super.totalBatches,
    required super.completedBatches,
    required super.inProgressBatches,
    required super.plannedBatches,
    required super.cancelledBatches,
    required super.completionRate,
    required super.productionQuantity,
    required super.defectsQuantity,
    required super.dailyTrend,
    required super.machineStats,
  });

  factory ProductionAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return ProductionAnalyticsModel(
      totalBatches: (json['total_batches'] as num?)?.toInt() ?? 0,
      completedBatches: (json['completed_batches'] as num?)?.toInt() ?? 0,
      inProgressBatches: (json['in_progress_batches'] as num?)?.toInt() ?? 0,
      plannedBatches: (json['planned_batches'] as num?)?.toInt() ?? 0,
      cancelledBatches: (json['cancelled_batches'] as num?)?.toInt() ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      productionQuantity: (json['production_quantity'] as num?)?.toInt() ?? 0,
      defectsQuantity: (json['defects_quantity'] as num?)?.toInt() ?? 0,
      dailyTrend: (json['daily_trend'] as List<dynamic>?)
              ?.map((e) => DailyProductionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      machineStats: (json['machine_stats'] as List<dynamic>?)
              ?.map((e) => MachineStatModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DailyProductionModel extends DailyProductionEntity {
  const DailyProductionModel({
    required super.date,
    required super.quantity,
  });

  factory DailyProductionModel.fromJson(Map<String, dynamic> json) {
    return DailyProductionModel(
      date: DateTime.parse(json['date'] as String),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class MachineStatModel extends MachineStatEntity {
  const MachineStatModel({
    required super.machineName,
    required super.batchCount,
    required super.completedCount,
  });

  factory MachineStatModel.fromJson(Map<String, dynamic> json) {
    return MachineStatModel(
      machineName: json['machine_name'] as String? ?? '',
      batchCount: (json['batch_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
    );
  }
}
