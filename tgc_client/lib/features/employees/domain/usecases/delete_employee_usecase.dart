import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/employee_repository.dart';

class DeleteEmployeeUseCase {
  final EmployeeRepository _repository;

  const DeleteEmployeeUseCase(this._repository);

  Future<Either<Failure, void>> call({required int id}) =>
      _repository.deleteEmployee(id: id);
}
