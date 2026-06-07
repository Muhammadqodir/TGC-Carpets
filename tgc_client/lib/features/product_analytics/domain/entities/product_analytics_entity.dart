import 'package:equatable/equatable.dart';

class AnalyticsDimensionItem extends Equatable {
  final int? id;
  final String name;
  final int ordersCount;
  final int totalQuantity;
  final double percentage;

  const AnalyticsDimensionItem({
    required this.id,
    required this.name,
    required this.ordersCount,
    required this.totalQuantity,
    required this.percentage,
  });

  @override
  List<Object?> get props => [id, name, ordersCount, totalQuantity, percentage];
}

class AnalyticsTrendPoint extends Equatable {
  final String label;
  final int ordersCount;
  final int totalQuantity;

  const AnalyticsTrendPoint({
    required this.label,
    required this.ordersCount,
    required this.totalQuantity,
  });

  @override
  List<Object?> get props => [label, ordersCount, totalQuantity];
}

class ProductColorBreakdown extends Equatable {
  final String name;
  final String? imageUrl;
  final int quantity;
  final double percentage;

  const ProductColorBreakdown({
    required this.name,
    this.imageUrl,
    required this.quantity,
    required this.percentage,
  });

  @override
  List<Object?> get props => [name, imageUrl, quantity, percentage];
}

class ProductSizeBreakdown extends Equatable {
  final String label;
  final int? width;
  final int? length;
  final int quantity;
  final double percentage;

  const ProductSizeBreakdown({
    required this.label,
    required this.width,
    required this.length,
    required this.quantity,
    required this.percentage,
  });

  @override
  List<Object?> get props => [label, width, length, quantity, percentage];
}

class TopProductItem extends Equatable {
  final int? id;
  final String name;
  final String typeName;
  final String qualityName;
  final int ordersCount;
  final int totalQuantity;
  final double percentage;
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
    required this.colors,
    required this.sizes,
  });

  @override
  List<Object?> get props =>
      [id, name, typeName, qualityName, ordersCount, totalQuantity, percentage, colors, sizes];
}

class AnalyticsSummary extends Equatable {
  final int totalOrders;
  final int totalItems;

  const AnalyticsSummary({
    required this.totalOrders,
    required this.totalItems,
  });

  @override
  List<Object?> get props => [totalOrders, totalItems];
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
        topProducts,
      ];
}
