import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/employee_entity.dart';
import '../repositories/employee_repository.dart';

class UpdateEmployeeUseCase {
  final EmployeeRepository _repository;
  const UpdateEmployeeUseCase(this._repository);

  Future<Either<Failure, EmployeeEntity>> call({
    required int id,
    String? name,
    String? email,
    String? phone,
    String? password,
    List<String>? roles,
  }) =>
      _repository.updateEmployee(
        id: id,
        name: name,
        email: email,
        phone: phone,
        password: password,
        roles: roles,
      );
}
