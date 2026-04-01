import 'package:equatable/equatable.dart';

abstract class EmployeeFormEvent extends Equatable {
  const EmployeeFormEvent();
  @override
  List<Object?> get props => [];
}

class EmployeeFormSubmitted extends EmployeeFormEvent {
  final String name;
  final String email;
  final String? phone;
  final String password;
  final String role;

  const EmployeeFormSubmitted({
    required this.name,
    required this.email,
    this.phone,
    required this.password,
    required this.role,
  });

  @override
  List<Object?> get props => [name, email, phone, password, role];
}
