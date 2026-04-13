import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/shipment_entity.dart';
import '../../domain/repositories/shipment_repository.dart';
import '../datasources/shipment_remote_datasource.dart';

class ShipmentRepositoryImpl implements ShipmentRepository {
  final ShipmentRemoteDataSource remoteDataSource;

  const ShipmentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<ShipmentEntity>>> getShipments({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await remoteDataSource.getShipments(
        clientId: clientId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
        perPage: perPage,
      );
      return Right(
        PaginatedResponse<ShipmentEntity>(
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
}
