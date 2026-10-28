import '../../domain/entities/production_operations_entity.dart';

class ProductionCapacityStatsModel extends ProductionCapacityStats {
  const ProductionCapacityStatsModel({
    required super.id,
    required super.name,
    required super.totalQuantity,
    required super.totalSqm,
    required super.workingDays,
    required super.avgQuantityPerDay,
    required super.avgSqmPerDay,
    required super.bestDayQuantity,
    required super.bestDayQuantityDate,
    required super.bestDaySqm,
    required super.bestDaySqmDate,
    required super.utilizationQuantity,
    required super.utilizationSqm,
    required super.totalDefects,
    required super.defectRate,
    required super.reprints,
    required super.overTargetPrints,
  });

  factory ProductionCapacityStatsModel.fromJson(Map<String, dynamic> json) {
    double num0(String k) => (json[k] as num?)?.toDouble() ?? 0.0;
    double? numN(String k) => (json[k] as num?)?.toDouble();
    int int0(String k) => (json[k] as num?)?.toInt() ?? 0;

    return ProductionCapacityStatsModel(
      id:                  (json['id'] as num?)?.toInt(),
      name:                json['name'] as String? ?? '',
      totalQuantity:       int0('total_quantity'),
      totalSqm:            num0('total_sqm'),
      workingDays:         int0('working_days'),
      avgQuantityPerDay:   num0('avg_quantity_per_day'),
      avgSqmPerDay:        num0('avg_sqm_per_day'),
      bestDayQuantity:     int0('best_day_quantity'),
      bestDayQuantityDate: json['best_day_quantity_date'] as String?,
      bestDaySqm:          num0('best_day_sqm'),
      bestDaySqmDate:      json['best_day_sqm_date'] as String?,
      utilizationQuantity: numN('utilization_quantity'),
      utilizationSqm:      numN('utilization_sqm'),
      totalDefects:        int0('total_defects'),
      defectRate:          numN('defect_rate'),
      reprints:            int0('reprints'),
      overTargetPrints:    int0('over_target_prints'),
    );
  }
}

class ProductionOperationsModel extends ProductionOperationsEntity {
  const ProductionOperationsModel({
    required super.dayStartHour,
    required super.periodDays,
    required super.backfilledExcluded,
    required super.trendBy,
    required super.summary,
    required super.trend,
    required super.byShift,
    required super.byMachine,
    required super.heatmap,
  });

  factory ProductionOperationsModel.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? {};

    List<ProductionCapacityStats> rows(String key) => (json[key] as List<dynamic>? ?? [])
        .map((e) => ProductionCapacityStatsModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return ProductionOperationsModel(
      dayStartHour:       (json['day_start_hour'] as num?)?.toInt() ?? 0,
      periodDays:         (summary['period_days'] as num?)?.toInt() ?? 0,
      backfilledExcluded: (summary['backfilled_excluded'] as num?)?.toInt() ?? 0,
      trendBy:            (json['period'] as Map<String, dynamic>?)?['trend_by'] as String? ?? 'day',
      summary:            ProductionCapacityStatsModel.fromJson({...summary, 'name': 'Jami'}),
      trend: (json['trend'] as List<dynamic>? ?? []).map((e) {
        final t = e as Map<String, dynamic>;
        return ProductionShiftTrendPoint(
          label:         t['label'] as String? ?? '',
          userId:        (t['user_id'] as num?)?.toInt() ?? 0,
          totalQuantity: (t['total_quantity'] as num?)?.toInt() ?? 0,
          totalSqm:      (t['total_sqm'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList(),
      byShift:            rows('by_shift'),
      byMachine:          rows('by_machine'),
      heatmap: (json['heatmap'] as List<dynamic>? ?? []).map((e) {
        final c = e as Map<String, dynamic>;
        return ProductionHeatmapCell(
          userId:        (c['user_id'] as num?)?.toInt() ?? 0,
          weekday:       (c['weekday'] as num?)?.toInt() ?? 0,
          hour:          (c['hour'] as num?)?.toInt() ?? 0,
          totalQuantity: (c['total_quantity'] as num?)?.toInt() ?? 0,
          totalSqm:      (c['total_sqm'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList(),
    );
  }
}
