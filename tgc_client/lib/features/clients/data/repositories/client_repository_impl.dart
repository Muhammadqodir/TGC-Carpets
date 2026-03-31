import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/client_entity.dart';
import '../../domain/repositories/client_repository.dart';
import '../datasources/client_remote_datasource.dart';

class ClientRepositoryImpl implements ClientRepository {
  final ClientRemoteDataSource remoteDataSource;

  const ClientRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<ClientEntity>>> getClients({
    String? search,
    String? region,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await remoteDataSource.getClients(
        search: search,
        region: region,
        page: page,
        perPage: perPage,
      );
      return Right(
        PaginatedResponse<ClientEntity>(
          data: result.data,
          currentPage: result.currentPage,
          lastPage: result.lastPage,
          perPage: result.perPage,
          total: result.total,
        ),
      );
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ClientEntity>> getClient(int id) async {
    try {
      final client = await remoteDataSource.getClient(id);
      return Right(client);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ClientEntity>> createClient({
    required String contactName,
    required String phone,
    required String shopName,
    required String region,
    String? address,
    String? notes,
  }) async {
    try {
      final client = await remoteDataSource.createClient(
        contactName: contactName,
        phone: phone,
        shopName: shopName,
        region: region,
        address: address,
        notes: notes,
      );
      return Right(client);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
