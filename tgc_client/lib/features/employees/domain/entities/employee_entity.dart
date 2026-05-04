import 'package:equatable/equatable.dart';

class EmployeeEntity extends Equatable {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final List<String> roles;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.roles,
    required this.createdAt,
    required this.updatedAt,
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

  // Legacy helpers
  bool get isWarehouse => isWarehouseManager;
  bool get isSeller => isSalesManager;

  // For backward compatibility with single role field
  String get role => roles.isNotEmpty ? roles.first : '';

  String get roleLabel {
    if (roles.isEmpty) return '';
    if (roles.length == 1) {
      return switch (roles.first) {
        'admin' => 'Admin',
        'warehouse_manager' => 'Ombor Menejer',
        'sales_manager' => 'Savdo Menejer',
        'raw_warehouse_manager' => 'Xom Ashyo Menejer',
        'product_manager' => 'Mahsulot Menejer',
        'machine_manager' => 'Stanok Menejer',
        'production_manager' => 'Ishlab Chiqarish Menejer',
        'order_manager' => 'Buyurtma Menejer',
        'label_manager' => 'Yorliq Menejer',
        _ => roles.first,
      };
    }
    // Multiple roles: show count
    return '${roles.length} ta rol';
  }

  @override
  List<Object?> get props => [id, name, email, phone, roles, createdAt, updatedAt];
}
