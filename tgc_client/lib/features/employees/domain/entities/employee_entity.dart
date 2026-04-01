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
  bool get isWarehouse => role == 'warehouse';
  bool get isSeller => role == 'seller';

  String get roleLabel => switch (role) {
        'admin' => 'Admin',
        'warehouse' => 'Ombor',
        'seller' => 'Sotuvchi',
        _ => role,
      };

  @override
  List<Object?> get props => [id, name, email, phone, role, createdAt, updatedAt];
}
