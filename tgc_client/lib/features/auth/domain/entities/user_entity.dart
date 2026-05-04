import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final int id;
  final String name;
  final String email;
  final List<String> roles;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
  });

  bool hasRole(String role) => roles.contains(role);
  bool hasAnyRole(List<String> checkRoles) => roles.any((r) => checkRoles.contains(r));

  bool get isAdmin => hasRole('admin');
  bool get isWarehouseManager => hasRole('warehouse_manager');
  bool get isSalesManager => hasRole('sales_manager');
  bool get isRawWarehouseManager => hasRole('raw_warehouse_manager');
  bool get isProductManager => hasRole('product_manager');
  bool get isMachineManager => hasRole('machine_manager');
  bool get isProductionManager => hasRole('production_manager');
  bool get isOrderManager => hasRole('order_manager');
  bool get isLabelManager => hasRole('label_manager');

  // Legacy helpers for backward compatibility
  bool get isWarehouse => isWarehouseManager;
  bool get isSeller => isSalesManager;

  // For backward compatibility with single role field
  String get role => roles.isNotEmpty ? roles.first : '';

  @override
  List<Object?> get props => [id, name, email, roles];
}
