import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/client_entity.dart';

abstract class ClientRepository {
  Future<Either<Failure, PaginatedResponse<ClientEntity>>> getClients({
    String? search,
    String? region,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, ClientEntity>> getClient(int id);

  Future<Either<Failure, ClientEntity>> createClient({
    required String contactName,
    required String phone,
    required String shopName,
    required String region,
    String? address,
    String? notes,
  });

  Future<Either<Failure, ClientEntity>> updateClient({
    required int id,
    required String contactName,
    required String phone,
    required String shopName,
    required String region,
    String? address,
    String? notes,
  });

  Future<Either<Failure, void>> deleteClient({required int id});
}
