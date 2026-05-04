import 'package:tgc_client/features/analytics/domain/entities/financial_analytics_entity.dart';

class FinancialAnalyticsModel extends FinancialAnalyticsEntity {
  const FinancialAnalyticsModel({
    required super.totalRevenue,
    required super.totalPayments,
    required super.outstandingDebt,
    required super.revenueMinusPayments,
    required super.topDebtors,
    required super.dailyPayments,
  });

  factory FinancialAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return FinancialAnalyticsModel(
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalPayments: (json['total_payments'] as num?)?.toDouble() ?? 0.0,
      outstandingDebt: (json['outstanding_debt'] as num?)?.toDouble() ?? 0.0,
      revenueMinusPayments: (json['revenue_minus_payments'] as num?)?.toDouble() ?? 0.0,
      topDebtors: (json['top_debtors'] as List<dynamic>?)
              ?.map((e) => TopDebtorModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dailyPayments: (json['daily_payments'] as List<dynamic>?)
              ?.map((e) => DailyPaymentModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TopDebtorModel extends TopDebtorEntity {
  const TopDebtorModel({
    required super.id,
    required super.contactName,
    required super.shopName,
    required super.region,
    required super.totalSales,
    required super.totalPayments,
    required super.debt,
  });

  factory TopDebtorModel.fromJson(Map<String, dynamic> json) {
    return TopDebtorModel(
      id: json['id'] as int,
      contactName: json['contact_name'] as String? ?? '',
      shopName: json['shop_name'] as String? ?? '',
      region: json['region'] as String? ?? '',
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0.0,
      totalPayments: (json['total_payments'] as num?)?.toDouble() ?? 0.0,
      debt: (json['debt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DailyPaymentModel extends DailyPaymentEntity {
  const DailyPaymentModel({
    required super.date,
    required super.amount,
    required super.count,
  });

  factory DailyPaymentModel.fromJson(Map<String, dynamic> json) {
    return DailyPaymentModel(
      date: DateTime.parse(json['date'] as String),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}
