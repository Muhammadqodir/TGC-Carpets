import 'package:equatable/equatable.dart';
import '../../domain/entities/employee_entity.dart';

abstract class EmployeesState extends Equatable {
  const EmployeesState();
  @override
  List<Object?> get props => [];
}

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

  const EmployeesLoaded({
    required this.employees,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    this.activeRole,
  });

  EmployeesLoaded copyWith({
    List<EmployeeEntity>? employees,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    String? activeRole,
    bool clearRole = false,
  }) =>
      EmployeesLoaded(
        employees: employees ?? this.employees,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        activeRole: clearRole ? null : (activeRole ?? this.activeRole),
      );

  @override
  List<Object?> get props => [employees, hasNextPage, isLoadingMore, currentPage, activeRole];
}

class EmployeesError extends EmployeesState {
  final String message;
  const EmployeesError(this.message);
  @override
  List<Object?> get props => [message];
}
