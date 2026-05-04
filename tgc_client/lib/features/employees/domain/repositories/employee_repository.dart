import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/employee_entity.dart';

abstract class EmployeeRepository {
  Future<Either<Failure, PaginatedResponse<EmployeeEntity>>> getEmployees({
    String? search,
    String? role,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, EmployeeEntity>> createEmployee({
    required String name,
    required String email,
    String? phone,
    required String password,
    required List<String> roles,
  });

  Future<Either<Failure, EmployeeEntity>> updateEmployee({
    required int id,
    String? name,
    String? email,
    String? phone,
    String? password,
    List<String>? roles,
  });

  Future<Either<Failure, void>> deleteEmployee({required int id});
}
