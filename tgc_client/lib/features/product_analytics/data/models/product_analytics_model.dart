import '../../domain/entities/product_analytics_entity.dart';

class ProductColorBreakdownModel extends ProductColorBreakdown {
  const ProductColorBreakdownModel({
    required super.name,
    required super.quantity,
    required super.percentage,
  });

  factory ProductColorBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ProductColorBreakdownModel(
      name:       json['name'] as String? ?? '',
      quantity:   json['quantity'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProductSizeBreakdownModel extends ProductSizeBreakdown {
  const ProductSizeBreakdownModel({
    required super.label,
    required super.width,
    required super.length,
    required super.quantity,
    required super.percentage,
  });

  factory ProductSizeBreakdownModel.fromJson(Map<String, dynamic> json) {
    return ProductSizeBreakdownModel(
      label:      json['label'] as String? ?? '',
      width:      json['width'] as int?,
      length:     json['length'] as int?,
      quantity:   json['quantity'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TopProductItemModel extends TopProductItem {
  const TopProductItemModel({
    required super.id,
    required super.name,
    required super.typeName,
    required super.qualityName,
    required super.ordersCount,
    required super.totalQuantity,
    required super.percentage,
    required super.colors,
    required super.sizes,
  });

  factory TopProductItemModel.fromJson(Map<String, dynamic> json) {
    return TopProductItemModel(
      id:            json['id'] as int?,
      name:          json['name'] as String? ?? '',
      typeName:      json['type_name'] as String? ?? '',
      qualityName:   json['quality_name'] as String? ?? '',
      ordersCount:   json['orders_count'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
      percentage:    (json['percentage'] as num?)?.toDouble() ?? 0.0,
      colors: (json['colors'] as List<dynamic>? ?? [])
          .map((e) => ProductColorBreakdownModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      sizes: (json['sizes'] as List<dynamic>? ?? [])
          .map((e) => ProductSizeBreakdownModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AnalyticsDimensionItemModel extends AnalyticsDimensionItem {
  const AnalyticsDimensionItemModel({
    required super.id,
    required super.name,
    required super.ordersCount,
    required super.totalQuantity,
    required super.percentage,
  });

  factory AnalyticsDimensionItemModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsDimensionItemModel(
      id:             json['id'] as int?,
      name:           json['name'] as String? ?? '',
      ordersCount:    json['orders_count'] as int? ?? 0,
      totalQuantity:  json['total_quantity'] as int? ?? 0,
      percentage:     (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AnalyticsTrendPointModel extends AnalyticsTrendPoint {
  const AnalyticsTrendPointModel({
    required super.label,
    required super.ordersCount,
    required super.totalQuantity,
  });

  factory AnalyticsTrendPointModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsTrendPointModel(
      label:          json['label'] as String? ?? '',
      ordersCount:    json['orders_count'] as int? ?? 0,
      totalQuantity:  json['total_quantity'] as int? ?? 0,
    );
  }
}

class AnalyticsSummaryModel extends AnalyticsSummary {
  const AnalyticsSummaryModel({
    required super.totalOrders,
    required super.totalItems,
  });

  factory AnalyticsSummaryModel.fromJson(Map<String, dynamic> json) {
    return AnalyticsSummaryModel(
      totalOrders: json['total_orders'] as int? ?? 0,
      totalItems:  json['total_items'] as int? ?? 0,
    );
  }
}

class ProductAnalyticsModel extends ProductAnalyticsEntity {
  const ProductAnalyticsModel({
    required super.periodFrom,
    required super.periodTo,
    required super.trendBy,
    required super.summary,
    required super.trend,
    required super.byType,
    required super.byColor,
    required super.bySize,
    required super.byQuality,
    required super.topProducts,
  });

  factory ProductAnalyticsModel.fromJson(Map<String, dynamic> json) {
    final period = json['period'] as Map<String, dynamic>? ?? {};

    List<AnalyticsDimensionItem> parseDimension(String key) {
      final list = json[key] as List<dynamic>? ?? [];
      return list
          .map((e) => AnalyticsDimensionItemModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return ProductAnalyticsModel(
      periodFrom: period['from'] as String? ?? '',
      periodTo:   period['to'] as String? ?? '',
      trendBy:    period['trend_by'] as String? ?? 'day',
      summary: AnalyticsSummaryModel.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      trend: (json['trend'] as List<dynamic>? ?? [])
          .map((e) => AnalyticsTrendPointModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      byType:       parseDimension('by_type'),
      byColor:      parseDimension('by_color'),
      bySize:       parseDimension('by_size'),
      byQuality:    parseDimension('by_quality'),
      topProducts: (json['top_products'] as List<dynamic>? ?? [])
          .map((e) => TopProductItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
