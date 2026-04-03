import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/sale_entity.dart';
import '../repositories/sale_repository.dart';

class GetSalesUseCase {
  final SaleRepository _repository;

  const GetSalesUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<SaleEntity>>> call({
    int? clientId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getSales(
        clientId: clientId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
        perPage: perPage,
      );
}
