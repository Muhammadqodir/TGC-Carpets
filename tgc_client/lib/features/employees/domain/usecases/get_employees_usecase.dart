import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

class GetEmployeesUseCase {
  final EmployeeRepository _repository;
  const GetEmployeesUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<EmployeeEntity>>> call({
    String? search,
    String? role,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getEmployees(search: search, role: role, page: page, perPage: perPage);
}
