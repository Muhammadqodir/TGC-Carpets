import 'package:equatable/equatable.dart';
import '../../domain/entities/employee_entity.dart';

abstract class EmployeesState extends Equatable {
  const EmployeesState();
  @override
  List<Object?> get props => [];
}

// ─── Action status ──────────────────────────────────────────────────────────

sealed class EmployeeActionStatus extends Equatable {
  const EmployeeActionStatus();
}

class EmployeeActionIdle extends EmployeeActionStatus {
  const EmployeeActionIdle();
  @override
  List<Object?> get props => [];
}

class EmployeeActionPending extends EmployeeActionStatus {
  final int employeeId;
  const EmployeeActionPending(this.employeeId);
  @override
  List<Object?> get props => [employeeId];
}

class EmployeeActionSuccess extends EmployeeActionStatus {
  final String message;
  const EmployeeActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class EmployeeActionFailure extends EmployeeActionStatus {
  final String message;
  const EmployeeActionFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Page states ─────────────────────────────────────────────────────────────

class EmployeesInitial extends EmployeesState {
  const EmployeesInitial();
}

class EmployeesLoading extends EmployeesState {
  const EmployeesLoading();
}

class EmployeesLoaded extends EmployeesState {
  final List<EmployeeEntity> employees;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;
  final String? activeRole;
  final int total;
  final EmployeeActionStatus actionStatus;

  const EmployeesLoaded({
    required this.employees,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    this.activeRole,
    required this.total,
    this.actionStatus = const EmployeeActionIdle(),
  });

  EmployeesLoaded copyWith({
    List<EmployeeEntity>? employees,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    String? activeRole,
    bool clearRole = false,
    int? total,
    EmployeeActionStatus? actionStatus,
  }) =>
      EmployeesLoaded(
        employees: employees ?? this.employees,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        activeRole: clearRole ? null : (activeRole ?? this.activeRole),
        total: total ?? this.total,
        actionStatus: actionStatus ?? this.actionStatus,
      );

  @override
  List<Object?> get props => [employees, hasNextPage, isLoadingMore, currentPage, activeRole, total, actionStatus];
}

class EmployeesError extends EmployeesState {
  final String message;
  const EmployeesError(this.message);
  @override
  List<Object?> get props => [message];
}
