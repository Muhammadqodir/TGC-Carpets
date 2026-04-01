import 'package:equatable/equatable.dart';
import '../../domain/entities/employee_entity.dart';

abstract class EmployeeFormState extends Equatable {
  const EmployeeFormState();
  @override
  List<Object?> get props => [];
}

class EmployeeFormInitial extends EmployeeFormState {
  const EmployeeFormInitial();
}

class EmployeeFormSubmitting extends EmployeeFormState {
  const EmployeeFormSubmitting();
}

class EmployeeFormSuccess extends EmployeeFormState {
  final EmployeeEntity employee;
  const EmployeeFormSuccess(this.employee);
  @override
  List<Object?> get props => [employee];
}

class EmployeeFormFailure extends EmployeeFormState {
  final String message;
  const EmployeeFormFailure(this.message);
  @override
  List<Object?> get props => [message];
}
