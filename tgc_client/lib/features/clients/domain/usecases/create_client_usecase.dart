import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/client_entity.dart';
import '../repositories/client_repository.dart';

class CreateClientUseCase {
  final ClientRepository _repository;

  const CreateClientUseCase(this._repository);

  Future<Either<Failure, ClientEntity>> call({
    required String contactName,
    required String phone,
    required String shopName,
    required String region,
    String? address,
    String? notes,
  }) =>
      _repository.createClient(
        contactName: contactName,
        phone: phone,
        shopName: shopName,
        region: region,
        address: address,
        notes: notes,
      );
}
