import 'package:equatable/equatable.dart';

class ProductionDimensionItem extends Equatable {
  final int? id;
  final String name;
  final int batchesCount;
  final int totalQuantity;
  final double totalSqm;
  final double percentage;

  const ProductionDimensionItem({
    required this.id,
    required this.name,
    required this.batchesCount,
    required this.totalQuantity,
    required this.totalSqm,
    required this.percentage,
  });

  @override
  List<Object?> get props =>
      [id, name, batchesCount, totalQuantity, totalSqm, percentage];
}

class ProductionTrendPoint extends Equatable {
  final String label;
  final int batchesCount;
  final int totalQuantity;
  final double totalSqm;

  const ProductionTrendPoint({
    required this.label,
    required this.batchesCount,
    required this.totalQuantity,
    required this.totalSqm,
  });

  @override
  List<Object?> get props => [label, batchesCount, totalQuantity, totalSqm];
}

class ProductionAnalyticsSummary extends Equatable {
  final int totalBatches;
  final int totalProduced;
  final double totalSqm;

  const ProductionAnalyticsSummary({
    required this.totalBatches,
    required this.totalProduced,
    required this.totalSqm,
  });

  @override
  List<Object?> get props => [totalBatches, totalProduced, totalSqm];
}

class ProductionAnalyticsEntity extends Equatable {
  final String periodFrom;
  final String periodTo;
  final String trendBy;
  final ProductionAnalyticsSummary summary;
  final List<ProductionTrendPoint> trend;
  final List<ProductionDimensionItem> byType;
  final List<ProductionDimensionItem> byColor;
  final List<ProductionDimensionItem> bySize;
  final List<ProductionDimensionItem> byQuality;
  final List<ProductionDimensionItem> byEdge;

  const ProductionAnalyticsEntity({
    required this.periodFrom,
    required this.periodTo,
    required this.trendBy,
    required this.summary,
    required this.trend,
    required this.byType,
    required this.byColor,
    required this.bySize,
    required this.byQuality,
    required this.byEdge,
  });

  @override
  List<Object?> get props => [
        periodFrom,
        periodTo,
        trendBy,
        summary,
        trend,
        byType,
        byColor,
        bySize,
        byQuality,
        byEdge,
      ];
}
