import 'package:equatable/equatable.dart';

class FinancialAnalyticsEntity extends Equatable {
  final double totalRevenue;
  final double totalPayments;
  final double outstandingDebt;
  final double revenueMinusPayments;
  final List<TopDebtorEntity> topDebtors;
  final List<DailyPaymentEntity> dailyPayments;

  const FinancialAnalyticsEntity({
    required this.totalRevenue,
    required this.totalPayments,
    required this.outstandingDebt,
    required this.revenueMinusPayments,
    required this.topDebtors,
    required this.dailyPayments,
  });

  @override
  List<Object?> get props => [
        totalRevenue,
        totalPayments,
        outstandingDebt,
        revenueMinusPayments,
        topDebtors,
        dailyPayments,
      ];
}

class TopDebtorEntity extends Equatable {
  final int id;
  final String contactName;
  final String shopName;
  final String region;
  final double totalSales;
  final double totalPayments;
  final double debt;

  const TopDebtorEntity({
    required this.id,
    required this.contactName,
    required this.shopName,
    required this.region,
    required this.totalSales,
    required this.totalPayments,
    required this.debt,
  });

  @override
  List<Object?> get props => [
        id,
        contactName,
        shopName,
        region,
        totalSales,
        totalPayments,
        debt,
      ];
}

class DailyPaymentEntity extends Equatable {
  final DateTime date;
  final double amount;
  final int count;

  const DailyPaymentEntity({
    required this.date,
    required this.amount,
    required this.count,
  });

  @override
  List<Object?> get props => [date, amount, count];
}
