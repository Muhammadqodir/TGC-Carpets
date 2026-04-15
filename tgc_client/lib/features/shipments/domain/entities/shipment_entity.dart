import 'package:equatable/equatable.dart';

import 'shipment_item_entity.dart';

class ShipmentEntity extends Equatable {
  final int id;
  final DateTime shipmentDatetime;
  final String? notes;
  final int? clientId;
  final String? clientShopName;
  final String? clientRegion;
  final int? userId;
  final String? userName;
  final List<ShipmentItemEntity> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShipmentEntity({
    required this.id,
    required this.shipmentDatetime,
    this.notes,
    this.clientId,
    this.clientShopName,
    this.clientRegion,
    this.userId,
    this.userName,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total pieces (unit == 'piece').
  int get totalPieces => items
      .where((i) => i.productUnit == 'piece')
      .fold(0, (sum, i) => sum + i.quantity);

  /// Total square metres across all m2 items (uses actual dimensions).
  double get totalM2 => items.fold(0.0, (sum, i) => sum + i.squareMeters);

  /// Total quantity across all items regardless of unit.
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);

  /// Grand total in USD.
  double get grandTotal => items.fold(0.0, (sum, i) => sum + i.lineTotal);

  /// Unique, sorted order dates from all items.
  List<DateTime> get orderDates {
    final seen = <String>{};
    final dates = <DateTime>[];
    for (final item in items) {
      if (item.orderDate != null) {
        final key = item.orderDate!.toIso8601String().substring(0, 10);
        if (seen.add(key)) dates.add(item.orderDate!);
      }
    }
    dates.sort((a, b) => a.compareTo(b));
    return dates;
  }

  @override
  List<Object?> get props => [
        id,
        shipmentDatetime,
        notes,
        clientId,
        clientShopName,
        clientRegion,
        userId,
        userName,
        items,
        createdAt,
        updatedAt,
      ];
}
