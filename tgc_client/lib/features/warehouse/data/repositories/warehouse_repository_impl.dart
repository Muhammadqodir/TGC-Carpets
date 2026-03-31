import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/warehouse_document_entity.dart';
import '../../domain/repositories/warehouse_repository.dart';
import '../datasources/warehouse_remote_datasource.dart';

class WarehouseRepositoryImpl implements WarehouseRepository {
  final WarehouseRemoteDataSource remoteDataSource;

  const WarehouseRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<WarehouseDocumentEntity>>>
      getDocuments({
    String? type,
    String? dateFrom,
    String? dateTo,
    int? clientId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await remoteDataSource.getDocuments(
        type: type,
        dateFrom: dateFrom,
        dateTo: dateTo,
        clientId: clientId,
        page: page,
        perPage: perPage,
      );
      return Right(
        PaginatedResponse<WarehouseDocumentEntity>(
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
  Future<Either<Failure, WarehouseDocumentEntity>> getDocument(int id) async {
    try {
      final document = await remoteDataSource.getDocument(id);
      return Right(document);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, WarehouseDocumentEntity>> createDocument({
    required String type,
    required String documentDate,
    required List<Map<String, dynamic>> items,
    int? clientId,
    String? notes,
    String? externalUuid,
  }) async {
    try {
      final document = await remoteDataSource.createDocument(
        type: type,
        documentDate: documentDate,
        items: items,
        clientId: clientId,
        notes: notes,
        externalUuid: externalUuid,
      );
      return Right(document);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
