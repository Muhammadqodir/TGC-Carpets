import 'package:equatable/equatable.dart';

/// Short axis label: 950, 12.5k, 1.2M. m² totals run into six figures and
/// don't fit the chart's left axis written out in full.
String compactNumber(num v) {
  String trim(double x) =>
      x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);
  final a = v.abs();
  if (a >= 1e6) return '${trim(v / 1e6)}M';
  if (a >= 1e3) return '${trim(v / 1e3)}k';
  return trim(v.toDouble());
}

/// What the order statistics page counts: carpets (dona) or area (m²).
enum AnalyticsMetric {
  quantity,
  sqm;

  /// Query value for the `metric` parameter of the top-products endpoint.
  String get apiValue => name;

  String get unit => this == quantity ? 'dona' : 'm²';

  /// Formats [v] with its unit, e.g. "12 dona" or "34.5 m²".
  String format(num v) =>
      this == quantity ? '${v.round()} $unit' : '${v.toStringAsFixed(1)} $unit';
}

class AnalyticsDimensionItem extends Equatable {
  final int? id;
  final String name;
  final int ordersCount;
  final int totalQuantity;
  final double percentage;
  final double totalSqm;
  final double sqmPercentage;

  const AnalyticsDimensionItem({
    required this.id,
    required this.name,
    required this.ordersCount,
    required this.totalQuantity,
    required this.percentage,
    this.totalSqm = 0,
    this.sqmPercentage = 0,
  });

  double valueOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? totalQuantity.toDouble() : totalSqm;

  double shareOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? percentage : sqmPercentage;

  @override
  List<Object?> get props =>
      [id, name, ordersCount, totalQuantity, percentage, totalSqm, sqmPercentage];
}

class AnalyticsTrendPoint extends Equatable {
  final String label;
  final int ordersCount;
  final int totalQuantity;
  final double totalSqm;

  const AnalyticsTrendPoint({
    required this.label,
    required this.ordersCount,
    required this.totalQuantity,
    this.totalSqm = 0,
  });

  double valueOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? totalQuantity.toDouble() : totalSqm;

  @override
  List<Object?> get props => [label, ordersCount, totalQuantity, totalSqm];
}

class ProductColorBreakdown extends Equatable {
  final String name;
  final String? imageUrl;
  final int quantity;
  final double percentage;
  final double sqm;
  final double sqmPercentage;

  const ProductColorBreakdown({
    required this.name,
    this.imageUrl,
    required this.quantity,
    required this.percentage,
    this.sqm = 0,
    this.sqmPercentage = 0,
  });

  double shareOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? percentage : sqmPercentage;

  @override
  List<Object?> get props => [name, imageUrl, quantity, percentage, sqm, sqmPercentage];
}

class ProductSizeBreakdown extends Equatable {
  final String label;
  final int? width;
  final int? length;
  final int quantity;
  final double percentage;
  final double sqm;
  final double sqmPercentage;

  const ProductSizeBreakdown({
    required this.label,
    required this.width,
    required this.length,
    required this.quantity,
    required this.percentage,
    this.sqm = 0,
    this.sqmPercentage = 0,
  });

  double shareOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? percentage : sqmPercentage;

  @override
  List<Object?> get props =>
      [label, width, length, quantity, percentage, sqm, sqmPercentage];
}

class TopProductItem extends Equatable {
  final int? id;
  final String name;
  final String typeName;
  final String qualityName;
  final int ordersCount;
  final int totalQuantity;
  final double percentage;
  final double totalSqm;
  final double sqmPercentage;
  final List<ProductColorBreakdown> colors;
  final List<ProductSizeBreakdown> sizes;

  const TopProductItem({
    required this.id,
    required this.name,
    required this.typeName,
    required this.qualityName,
    required this.ordersCount,
    required this.totalQuantity,
    required this.percentage,
    this.totalSqm = 0,
    this.sqmPercentage = 0,
    required this.colors,
    required this.sizes,
  });

  double valueOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? totalQuantity.toDouble() : totalSqm;

  double shareOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? percentage : sqmPercentage;

  @override
  List<Object?> get props => [
        id, name, typeName, qualityName, ordersCount, totalQuantity, percentage,
        totalSqm, sqmPercentage, colors, sizes,
      ];
}

class AnalyticsSummary extends Equatable {
  final int totalOrders;
  final int totalItems;
  final double totalSqm;

  const AnalyticsSummary({
    required this.totalOrders,
    required this.totalItems,
    this.totalSqm = 0,
  });

  @override
  List<Object?> get props => [totalOrders, totalItems, totalSqm];
}

class ProductAnalyticsEntity extends Equatable {
  final String periodFrom;
  final String periodTo;
  final String trendBy;
  final AnalyticsSummary summary;
  final List<AnalyticsTrendPoint> trend;
  final List<AnalyticsDimensionItem> byType;
  final List<AnalyticsDimensionItem> byColor;
  final List<AnalyticsDimensionItem> bySize;
  final List<AnalyticsDimensionItem> byQuality;
  final List<AnalyticsDimensionItem> byEdge;
  final List<TopProductItem> topProducts;

  const ProductAnalyticsEntity({
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
    required this.topProducts,
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
        topProducts,
      ];
}
