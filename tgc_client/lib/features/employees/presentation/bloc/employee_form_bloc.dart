import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/create_employee_usecase.dart';
import 'employee_form_event.dart';
import 'employee_form_state.dart';

class EmployeeFormBloc extends Bloc<EmployeeFormEvent, EmployeeFormState> {
  final CreateEmployeeUseCase _createEmployeeUseCase;

  EmployeeFormBloc({required CreateEmployeeUseCase createEmployeeUseCase})
      : _createEmployeeUseCase = createEmployeeUseCase,
        super(const EmployeeFormInitial()) {
    on<EmployeeFormSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
      EmployeeFormSubmitted event, Emitter<EmployeeFormState> emit) async {
    emit(const EmployeeFormSubmitting());
    final result = await _createEmployeeUseCase(
      name: event.name,
      email: event.email,
      phone: event.phone,
      password: event.password,
      role: event.role,
    );
    result.fold(
      (failure) => emit(EmployeeFormFailure(failure.message)),
      (employee) => emit(EmployeeFormSuccess(employee)),
    );
  }
}
