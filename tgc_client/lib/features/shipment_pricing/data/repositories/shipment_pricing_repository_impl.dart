import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../shipments/domain/entities/shipment_entity.dart';
import '../../domain/repositories/shipment_pricing_repository.dart';
import '../datasources/shipment_pricing_remote_datasource.dart';

class ShipmentPricingRepositoryImpl implements ShipmentPricingRepository {
  final ShipmentPricingRemoteDataSource remoteDataSource;

  const ShipmentPricingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, ShipmentEntity>> getShipment(int id) async {
    try {
      return Right(await remoteDataSource.getShipment(id));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, ShipmentEntity>> updatePrices({
    required int id,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      return Right(await remoteDataSource.updatePrices(id: id, items: items));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, double?>> getLastPrice({
    required int variantId,
    required int clientId,
  }) async {
    try {
      return Right(await remoteDataSource.getLastPrice(
        variantId: variantId,
        clientId: clientId,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
