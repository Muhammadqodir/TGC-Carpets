import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

class CreateEmployeeUseCase {
  final EmployeeRepository _repository;
  const CreateEmployeeUseCase(this._repository);

  Future<Either<Failure, EmployeeEntity>> call({
    required String name,
    required String email,
    String? phone,
    required String password,
    required String role,
  }) =>
      _repository.createEmployee(
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: role,
      );
}
