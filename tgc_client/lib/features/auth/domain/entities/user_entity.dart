import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final int id;
  final String name;
  final String email;
  final String role;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
  bool get isWarehouseManager => role == 'warehouse_manager';
  bool get isSalesManager => role == 'sales_manager';
  bool get isRawWarehouseManager => role == 'raw_warehouse_manager';
  bool get isProductManager => role == 'product_manager';
  bool get isMachineManager => role == 'machine_manager';
  bool get isProductionManager => role == 'production_manager';
  bool get isOrderManager => role == 'order_manager';
  bool get isLabelManager => role == 'label_manager';

  // Legacy helpers for backward compatibility
  bool get isWarehouse => isWarehouseManager;
  bool get isSeller => isSalesManager;

  @override
  List<Object?> get props => [id, name, email, role];
}
