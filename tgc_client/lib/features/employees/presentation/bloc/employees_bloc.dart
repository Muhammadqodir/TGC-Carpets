import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/usecases/delete_employee_usecase.dart';
import '../../domain/usecases/get_employees_usecase.dart';
import 'employees_event.dart';
import 'employees_state.dart';

class EmployeesBloc extends Bloc<EmployeesEvent, EmployeesState> {
  final GetEmployeesUseCase _getEmployeesUseCase;
  final DeleteEmployeeUseCase _deleteEmployeeUseCase;
  String _searchQuery = '';
  String? _activeRole;
  Timer? _debounce;

  EmployeesBloc({
    required GetEmployeesUseCase getEmployeesUseCase,
    required DeleteEmployeeUseCase deleteEmployeeUseCase,
  })  : _getEmployeesUseCase = getEmployeesUseCase,
        _deleteEmployeeUseCase = deleteEmployeeUseCase,
        super(const EmployeesInitial()) {
    on<EmployeesLoadRequested>(_onLoadRequested);
    on<EmployeesRefreshRequested>(_onRefreshRequested);
    on<EmployeesNextPageRequested>(_onNextPageRequested);
    on<EmployeesSearchChanged>(_onSearchChanged);
    on<EmployeesRoleFilterChanged>(_onRoleFilterChanged);
    on<EmployeeDeleteRequested>(_onDelete);
  }

  Future<void> _onLoadRequested(
      EmployeesLoadRequested event, Emitter<EmployeesState> emit) async {
    emit(const EmployeesLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
      EmployeesRefreshRequested event, Emitter<EmployeesState> emit) async {
    emit(const EmployeesLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  void _onSearchChanged(EmployeesSearchChanged event, Emitter<EmployeesState> emit) {
    _searchQuery = event.query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      add(const EmployeesLoadRequested());
    });
  }

  void _onRoleFilterChanged(
      EmployeesRoleFilterChanged event, Emitter<EmployeesState> emit) {
    _activeRole = event.role;
    add(const EmployeesLoadRequested());
  }

  Future<void> _onNextPageRequested(
      EmployeesNextPageRequested event, Emitter<EmployeesState> emit) async {
    final current = state;
    if (current is! EmployeesLoaded || !current.hasNextPage || current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  Future<void> _fetchPage(Emitter<EmployeesState> emit,
      {required int page, required bool replace}) async {
    final result = await _getEmployeesUseCase(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      role: _activeRole,
      page: page,
    );
    result.fold(
      (failure) => emit(EmployeesError(failure.message)),
      (paginated) {
        final existing = (!replace && state is EmployeesLoaded)
            ? (state as EmployeesLoaded).employees
            : <EmployeeEntity>[];
        emit(EmployeesLoaded(
          employees: [...existing, ...paginated.data],
          hasNextPage: paginated.hasNextPage,
          currentPage: paginated.currentPage,
          activeRole: _activeRole,
          total: paginated.total,
        ));
      },
    );
  }

  Future<void> _onDelete(
    EmployeeDeleteRequested event,
    Emitter<EmployeesState> emit,
  ) async {
    final current = state;
    if (current is! EmployeesLoaded) return;

    final idx = current.employees.indexWhere((e) => e.id == event.employeeId);
    if (idx == -1) return;
    final employee = current.employees[idx];

    emit(current.copyWith(actionStatus: EmployeeActionPending(event.employeeId)));

    final result = await _deleteEmployeeUseCase(id: event.employeeId);

    result.fold(
      (failure) => emit(current.copyWith(
        actionStatus: EmployeeActionFailure(failure.message),
      )),
      (_) => emit(current.copyWith(
        employees: current.employees
            .where((e) => e.id != event.employeeId)
            .toList(),
        total: current.total > 0 ? current.total - 1 : 0,
        actionStatus: EmployeeActionSuccess('"${employee.name}" o\'chirildi.'),
      )),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
