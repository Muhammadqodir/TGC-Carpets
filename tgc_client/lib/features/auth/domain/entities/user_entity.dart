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
  bool get isWarehouse => role == 'warehouse';
  bool get isSeller => role == 'seller';

  @override
  List<Object?> get props => [id, name, email, role];
}
