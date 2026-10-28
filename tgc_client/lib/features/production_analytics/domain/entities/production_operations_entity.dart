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

  /// Labels printed that did not count a carpet.
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

class ProductionOperationsEntity extends Equatable {
  /// Local hour a production day starts at (a night shift is one day).
  final int dayStartHour;
  final int periodDays;

  /// Pre-July carpets left out: they have no shift, hour or real day.
  final int backfilledExcluded;
  final ProductionCapacityStats summary;
  final List<ProductionCapacityStats> byShift;
  final List<ProductionCapacityStats> byMachine;
  final List<ProductionHeatmapCell> heatmap;

  const ProductionOperationsEntity({
    required this.dayStartHour,
    required this.periodDays,
    required this.backfilledExcluded,
    required this.summary,
    required this.byShift,
    required this.byMachine,
    required this.heatmap,
  });

  @override
  List<Object?> get props =>
      [dayStartHour, periodDays, backfilledExcluded, summary, byShift, byMachine, heatmap];
}
