import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/client_entity.dart';
import '../repositories/client_repository.dart';

class UpdateClientUseCase {
  final ClientRepository _repository;

  const UpdateClientUseCase(this._repository);

  Future<Either<Failure, ClientEntity>> call({
    required int id,
    String? contactName,
    String? phone,
    required String shopName,
    required String region,
    String? address,
    String? notes,
  }) =>
      _repository.updateClient(
        id: id,
        contactName: contactName,
        phone: phone,
        shopName: shopName,
        region: region,
        address: address,
        notes: notes,
      );
}
