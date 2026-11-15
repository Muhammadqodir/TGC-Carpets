import 'package:equatable/equatable.dart';

import '../../../product_analytics/domain/entities/product_analytics_entity.dart';

/// Output and capacity of one shift (the account that printed the labels),
/// one machine, or the whole factory. Capacity is the best production day
/// in the period; utilisation is the average working day against it.
class ProductionCapacityStats extends Equatable {
  final int? id;
  final String name;
  final int totalQuantity;
  final double totalSqm;
  final int workingDays;
  final double avgQuantityPerDay;
  final double avgSqmPerDay;
  final int bestDayQuantity;
  final String? bestDayQuantityDate;
  final double bestDaySqm;
  final String? bestDaySqmDate;
  final double? utilizationQuantity;
  final double? utilizationSqm;
  final int totalDefects;
  final double? defectRate;
  final int reprints;
  final int overTargetPrints;

  const ProductionCapacityStats({
    required this.id,
    required this.name,
    required this.totalQuantity,
    required this.totalSqm,
    required this.workingDays,
    required this.avgQuantityPerDay,
    required this.avgSqmPerDay,
    required this.bestDayQuantity,
    required this.bestDayQuantityDate,
    required this.bestDaySqm,
    required this.bestDaySqmDate,
    required this.utilizationQuantity,
    required this.utilizationSqm,
    required this.totalDefects,
    required this.defectRate,
    required this.reprints,
    required this.overTargetPrints,
  });

  double totalOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? totalQuantity.toDouble() : totalSqm;

  double avgOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? avgQuantityPerDay : avgSqmPerDay;

  double bestOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? bestDayQuantity.toDouble() : bestDaySqm;

  String? bestDateOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? bestDayQuantityDate : bestDaySqmDate;

  double? utilizationOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? utilizationQuantity : utilizationSqm;

  /// Labels printed that did not count a carpet. Shown as one "qayta chop"
  /// figure: over-target prints are reprints too, as far as the floor goes.
  int get extraPrints => reprints + overTargetPrints;

  @override
  List<Object?> get props => [
        id,
        name,
        totalQuantity,
        totalSqm,
        workingDays,
        avgQuantityPerDay,
        avgSqmPerDay,
        bestDayQuantity,
        bestDayQuantityDate,
        bestDaySqm,
        bestDaySqmDate,
        utilizationQuantity,
        utilizationSqm,
        totalDefects,
        defectRate,
        reprints,
        overTargetPrints,
      ];
}

class ProductionHeatmapCell extends Equatable {
  final int userId;

  /// 0 = Monday … 6 = Sunday.
  final int weekday;
  final int hour;
  final int totalQuantity;
  final double totalSqm;

  const ProductionHeatmapCell({
    required this.userId,
    required this.weekday,
    required this.hour,
    required this.totalQuantity,
    required this.totalSqm,
  });

  double valueOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? totalQuantity.toDouble() : totalSqm;

  @override
  List<Object?> get props => [userId, weekday, hour, totalQuantity, totalSqm];
}

/// One shift's output in one period bucket (production day, week or month).
class ProductionShiftTrendPoint extends Equatable {
  final String label;
  final int userId;
  final int totalQuantity;
  final double totalSqm;

  const ProductionShiftTrendPoint({
    required this.label,
    required this.userId,
    required this.totalQuantity,
    required this.totalSqm,
  });

  double valueOf(AnalyticsMetric m) =>
      m == AnalyticsMetric.quantity ? totalQuantity.toDouble() : totalSqm;

  @override
  List<Object?> get props => [label, userId, totalQuantity, totalSqm];
}

/// One shift's printed output of one product quality.
class ProductionShiftQualityRow extends Equatable {
  final int userId;
  final int? qualityId;
  final String qualityName;
  final int totalQuantity;
  final double totalSqm;

  const ProductionShiftQualityRow({
    required this.userId,
    required this.qualityId,
    required this.qualityName,
    required this.totalQuantity,
    required this.totalSqm,
  });

  @override
  List<Object?> get props => [userId, qualityId, qualityName, totalQuantity, totalSqm];
}

/// One shift's Kovrolin rolls of one width (cm). Lengths vary per roll, so
/// only the width groups them; m² carries the real printed lengths.
class ProductionShiftWidthRow extends Equatable {
  final int userId;
  final int? width;
  final int totalQuantity;
  final double totalSqm;

  const ProductionShiftWidthRow({
    required this.userId,
    required this.width,
    required this.totalQuantity,
    required this.totalSqm,
  });

  @override
  List<Object?> get props => [userId, width, totalQuantity, totalSqm];
}

class ProductionOperationsEntity extends Equatable {
  /// Local hour a production day starts at (a night shift is one day).
  final int dayStartHour;
  final int periodDays;

  /// Pre-July carpets left out: they have no shift, hour or real day.
  final int backfilledExcluded;
  final String trendBy;
  final ProductionCapacityStats summary;
  final List<ProductionShiftTrendPoint> trend;
  final List<ProductionCapacityStats> byShift;
  final List<ProductionCapacityStats> byMachine;
  final List<ProductionHeatmapCell> heatmap;
  final List<ProductionShiftQualityRow> byShiftQuality;

  /// Kovrolin only.
  final List<ProductionShiftWidthRow> byShiftWidth;

  const ProductionOperationsEntity({
    required this.dayStartHour,
    required this.periodDays,
    required this.backfilledExcluded,
    required this.trendBy,
    required this.summary,
    required this.trend,
    required this.byShift,
    required this.byMachine,
    required this.heatmap,
    this.byShiftQuality = const [],
    this.byShiftWidth = const [],
  });

  @override
  List<Object?> get props => [
        dayStartHour,
        periodDays,
        backfilledExcluded,
        trendBy,
        summary,
        trend,
        byShift,
        byMachine,
        heatmap,
        byShiftQuality,
        byShiftWidth,
      ];
}
