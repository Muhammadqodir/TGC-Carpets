import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/client_repository.dart';

class DeleteClientUseCase {
  final ClientRepository _repository;

  const DeleteClientUseCase(this._repository);

  Future<Either<Failure, void>> call({required int id}) =>
      _repository.deleteClient(id: id);
}
