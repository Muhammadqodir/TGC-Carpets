import 'package:equatable/equatable.dart';

class ClientAnalyticsEntity extends Equatable {
  final List<TopClientEntity> topClients;
  final List<RegionSalesEntity> salesByRegion;
  final List<ClientFrequencyEntity> clientFrequency;

  const ClientAnalyticsEntity({
    required this.topClients,
    required this.salesByRegion,
    required this.clientFrequency,
  });

  @override
  List<Object?> get props => [topClients, salesByRegion, clientFrequency];
}

class TopClientEntity extends Equatable {
  final int id;
  final String contactName;
  final String shopName;
  final String region;
  final double totalRevenue;
  final int shipmentCount;
  final int totalQuantity;

  const TopClientEntity({
    required this.id,
    required this.contactName,
    required this.shopName,
    required this.region,
    required this.totalRevenue,
    required this.shipmentCount,
    required this.totalQuantity,
  });

  @override
  List<Object?> get props => [
        id,
        contactName,
        shopName,
        region,
        totalRevenue,
        shipmentCount,
        totalQuantity,
      ];
}

class RegionSalesEntity extends Equatable {
  final String region;
  final double totalRevenue;
  final int shipmentCount;
  final int totalQuantity;

  const RegionSalesEntity({
    required this.region,
    required this.totalRevenue,
    required this.shipmentCount,
    required this.totalQuantity,
  });

  @override
  List<Object?> get props => [region, totalRevenue, shipmentCount, totalQuantity];
}

class ClientFrequencyEntity extends Equatable {
  final int id;
  final String contactName;
  final String shopName;
  final int orderCount;

  const ClientFrequencyEntity({
    required this.id,
    required this.contactName,
    required this.shopName,
    required this.orderCount,
  });

  @override
  List<Object?> get props => [id, contactName, shopName, orderCount];
}
