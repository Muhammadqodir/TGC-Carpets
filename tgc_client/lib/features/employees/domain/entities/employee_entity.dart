import 'package:equatable/equatable.dart';

class EmployeeEntity extends Equatable {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EmployeeEntity({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
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

  // Legacy helpers
  bool get isWarehouse => isWarehouseManager;
  bool get isSeller => isSalesManager;

  String get roleLabel => switch (role) {
        'admin' => 'Admin',
        'warehouse_manager' => 'Ombor Menejer',
        'sales_manager' => 'Savdo Menejer',
        'raw_warehouse_manager' => 'Xom Ashyo Menejer',
        'product_manager' => 'Mahsulot Menejer',
        'machine_manager' => 'Stanok Menejer',
        'production_manager' => 'Ishlab Chiqarish Menejer',
        'order_manager' => 'Buyurtma Menejer',
        'label_manager' => 'Yorliq Menejer',
        _ => role,
      };

  @override
  List<Object?> get props => [id, name, email, phone, role, createdAt, updatedAt];
}
