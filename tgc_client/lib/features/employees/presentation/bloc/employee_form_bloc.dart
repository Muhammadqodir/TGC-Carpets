import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/create_employee_usecase.dart';
import '../../domain/usecases/update_employee_usecase.dart';
import 'employee_form_event.dart';
import 'employee_form_state.dart';

class EmployeeFormBloc extends Bloc<EmployeeFormEvent, EmployeeFormState> {
  final CreateEmployeeUseCase _createEmployeeUseCase;
  final UpdateEmployeeUseCase _updateEmployeeUseCase;

  EmployeeFormBloc({
    required CreateEmployeeUseCase createEmployeeUseCase,
    required UpdateEmployeeUseCase updateEmployeeUseCase,
  })  : _createEmployeeUseCase = createEmployeeUseCase,
        _updateEmployeeUseCase = updateEmployeeUseCase,
        super(const EmployeeFormInitial()) {
    on<EmployeeFormSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
      EmployeeFormSubmitted event, Emitter<EmployeeFormState> emit) async {
    emit(const EmployeeFormSubmitting());
    
    if (event.id == null) {
      // Create new employee
      if (event.password == null || event.password!.isEmpty) {
        emit(const EmployeeFormFailure('Parol majburiy.'));
        return;
      }
      final result = await _createEmployeeUseCase(
        name: event.name,
        email: event.email,
        phone: event.phone,
        password: event.password!,
        roles: event.roles,
      );
      result.fold(
        (failure) => emit(EmployeeFormFailure(failure.message)),
        (employee) => emit(EmployeeFormSuccess(employee)),
      );
    } else {
      // Update existing employee
      final result = await _updateEmployeeUseCase(
        id: event.id!,
        name: event.name,
        email: event.email,
        phone: event.phone,
        password: event.password,
        roles: event.roles,
      );
      result.fold(
        (failure) => emit(EmployeeFormFailure(failure.message)),
        (employee) => emit(EmployeeFormSuccess(employee)),
      );
    }
  }
}
