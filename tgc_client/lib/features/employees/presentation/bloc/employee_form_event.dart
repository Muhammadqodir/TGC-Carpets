import 'package:equatable/equatable.dart';

abstract class EmployeeFormEvent extends Equatable {
  const EmployeeFormEvent();
  @override
  List<Object?> get props => [];
}

class EmployeeFormSubmitted extends EmployeeFormEvent {
  final int? id; // null for create, set for update
  final String name;
  final String email;
  final String? phone;
  final String? password; // nullable for update
  final List<String> roles;

  const EmployeeFormSubmitted({
    this.id,
    required this.name,
    required this.email,
    this.phone,
    this.password,
    required this.roles,
  });

  @override
  List<Object?> get props => [id, name, email, phone, password, roles];
}
