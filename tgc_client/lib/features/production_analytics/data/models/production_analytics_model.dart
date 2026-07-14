import '../../domain/entities/production_analytics_entity.dart';

class ProductionDimensionItemModel extends ProductionDimensionItem {
  const ProductionDimensionItemModel({
    required super.id,
    required super.name,
    required super.batchesCount,
    required super.totalQuantity,
    required super.totalSqm,
    required super.percentage,
  });

  factory ProductionDimensionItemModel.fromJson(Map<String, dynamic> json) {
    return ProductionDimensionItemModel(
      id:            json['id'] as int?,
      name:          json['name'] as String? ?? '',
      batchesCount:  json['batches_count'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
      totalSqm:      (json['total_sqm'] as num?)?.toDouble() ?? 0.0,
      percentage:    (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProductionTrendPointModel extends ProductionTrendPoint {
  const ProductionTrendPointModel({
    required super.label,
    required super.batchesCount,
    required super.totalQuantity,
    required super.totalSqm,
  });

  factory ProductionTrendPointModel.fromJson(Map<String, dynamic> json) {
    return ProductionTrendPointModel(
      label:         json['label'] as String? ?? '',
      batchesCount:  json['batches_count'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
      totalSqm:      (json['total_sqm'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProductionAnalyticsSummaryModel extends ProductionAnalyticsSummary {
  const ProductionAnalyticsSummaryModel({
    required super.totalBatches,
    required super.totalProduced,
    required super.totalSqm,
  });

  factory ProductionAnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return ProductionAnalyticsSummaryModel(
      totalBatches:  json['total_batches'] as int? ?? 0,
      totalProduced: json['total_produced'] as int? ?? 0,
      totalSqm:      (json['total_sqm'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProductionAnalyticsModel extends ProductionAnalyticsEntity {
  const ProductionAnalyticsModel({
    required super.periodFrom,
    required super.periodTo,
    required super.trendBy,
    required super.summary,
    required super.trend,
    required super.byType,
    required super.byColor,
    required super.bySize,
    required super.byQuality,
    required super.byEdge,
  });

  factory ProductionAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>? ?? {};

    List<ProductionDimensionItem> parseDimension(String key) {
      final list = json[key] as List<dynamic>? ?? [];
      return list
          .map((e) => ProductionDimensionItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return ProductionAnalyticsModel(
      periodFrom: period['from'] as String? ?? '',
      periodTo:   period['to'] as String? ?? '',
      trendBy:    period['trend_by'] as String? ?? 'day',
      summary: ProductionAnalyticsSummaryModel.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      trend: (json['trend'] as List<dynamic>? ?? [])
          .map((e) => ProductionTrendPointModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      byType:    parseDimension('by_type'),
      byColor:   parseDimension('by_color'),
      bySize:    parseDimension('by_size'),
      byQuality: parseDimension('by_quality'),
      byEdge:    parseDimension('by_edge'),
    );
  }
}
