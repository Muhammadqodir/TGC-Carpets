import 'package:tgc_client/features/analytics/domain/entities/client_analytics_entity.dart';

class ClientAnalyticsModel extends ClientAnalyticsEntity {
  const ClientAnalyticsModel({
    required super.topClients,
    required super.salesByRegion,
    required super.clientFrequency,
  });

  factory ClientAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return ClientAnalyticsModel(
      topClients: (json['top_clients'] as List<dynamic>?)
              ?.map((e) => TopClientModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      salesByRegion: (json['sales_by_region'] as List<dynamic>?)
              ?.map((e) => RegionSalesModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      clientFrequency: (json['client_frequency'] as List<dynamic>?)
              ?.map((e) => ClientFrequencyModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TopClientModel extends TopClientEntity {
  const TopClientModel({
    required super.id,
    required super.contactName,
    required super.shopName,
    required super.region,
    required super.totalRevenue,
    required super.shipmentCount,
    required super.totalQuantity,
  });

  factory TopClientModel.fromJson(Map<String, dynamic> json) {
    return TopClientModel(
      id: json['id'] as int,
      contactName: json['contact_name'] as String? ?? '',
      shopName: json['shop_name'] as String? ?? '',
      region: json['region'] as String? ?? '',
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      shipmentCount: (json['shipment_count'] as num?)?.toInt() ?? 0,
      totalQuantity: (json['total_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class RegionSalesModel extends RegionSalesEntity {
  const RegionSalesModel({
    required super.region,
    required super.totalRevenue,
    required super.shipmentCount,
    required super.totalQuantity,
  });

  factory RegionSalesModel.fromJson(Map<String, dynamic> json) {
    return RegionSalesModel(
      region: json['region'] as String? ?? '',
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      shipmentCount: (json['shipment_count'] as num?)?.toInt() ?? 0,
      totalQuantity: (json['total_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}

class ClientFrequencyModel extends ClientFrequencyEntity {
  const ClientFrequencyModel({
    required super.id,
    required super.contactName,
    required super.shopName,
    required super.orderCount,
  });

  factory ClientFrequencyModel.fromJson(Map<String, dynamic> json) {
    return ClientFrequencyModel(
      id: json['id'] as int,
      contactName: json['contact_name'] as String? ?? '',
      shopName: json['shop_name'] as String? ?? '',
      orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
    );
  }
}
