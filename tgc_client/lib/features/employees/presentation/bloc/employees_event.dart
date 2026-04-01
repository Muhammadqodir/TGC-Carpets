import 'package:equatable/equatable.dart';

abstract class EmployeesEvent extends Equatable {
  const EmployeesEvent();
  @override
  List<Object?> get props => [];
}

class EmployeesLoadRequested extends EmployeesEvent {
  const EmployeesLoadRequested();
}

class EmployeesRefreshRequested extends EmployeesEvent {
  const EmployeesRefreshRequested();
}

class EmployeesNextPageRequested extends EmployeesEvent {
  const EmployeesNextPageRequested();
}

class EmployeesSearchChanged extends EmployeesEvent {
  final String query;
  const EmployeesSearchChanged(this.query);
  @override
  List<Object?> get props => [query];
}

class EmployeesRoleFilterChanged extends EmployeesEvent {
  final String? role;
  const EmployeesRoleFilterChanged(this.role);
  @override
  List<Object?> get props => [role];
}
