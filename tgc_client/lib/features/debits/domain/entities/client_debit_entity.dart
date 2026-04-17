import 'package:equatable/equatable.dart';

class ClientDebitEntity extends Equatable {
  final int id;
  final String uuid;
  final String contactName;
  final String phone;
  final String shopName;
  final String region;
  final double totalDebit;
  final double totalCredit;
  final double balance;

  const ClientDebitEntity({
    required this.id,
    required this.uuid,
    required this.contactName,
    required this.phone,
    required this.shopName,
    required this.region,
    required this.totalDebit,
    required this.totalCredit,
    required this.balance,
  });

  @override
  List<Object?> get props => [
        id,
        uuid,
        contactName,
        phone,
        shopName,
        region,
        totalDebit,
        totalCredit,
        balance,
      ];
}
