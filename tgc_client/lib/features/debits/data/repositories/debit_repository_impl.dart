import 'package:dartz/dartz.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/client_debit_entity.dart';
import '../../domain/entities/debit_ledger_summary.dart';
import '../../domain/repositories/debit_repository.dart';
import '../datasources/debit_remote_datasource.dart';

class DebitRepositoryImpl implements DebitRepository {
  final DebitRemoteDataSource remoteDataSource;

  const DebitRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<ClientDebitEntity>>> getClientDebits({
    String? search,
    String? region,
    bool hasBalance = false,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await remoteDataSource.getClientDebits(
        search:     search,
        region:     region,
        hasBalance: hasBalance,
        page:       page,
        perPage:    perPage,
      );
      return Right(
        PaginatedResponse<ClientDebitEntity>(
          data:        result.data,
          currentPage: result.currentPage,
          lastPage:    result.lastPage,
          perPage:     result.perPage,
          total:       result.total,
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
  Future<Either<Failure, DebitLedgerSummary>> getClientDebitLedger(int clientId) async {
    try {
      final result = await remoteDataSource.getClientDebitLedger(clientId);
      return Right(
        DebitLedgerSummary(
          client:      result.client,
          totalDebit:  result.summary['total_debit']!,
          totalCredit: result.summary['total_credit']!,
          balance:     result.summary['balance']!,
          entries:     result.ledger,
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
