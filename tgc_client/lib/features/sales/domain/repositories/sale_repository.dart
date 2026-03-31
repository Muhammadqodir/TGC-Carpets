import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/sale_entity.dart';

abstract class SaleRepository {
  Future<Either<Failure, PaginatedResponse<SaleEntity>>> getSales({
    int? clientId,
    String? paymentStatus,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, SaleEntity>> getSale(int id);

  Future<Either<Failure, SaleEntity>> createSale({
    required int clientId,
    required String saleDate,
    required String paymentStatus,
    required List<Map<String, dynamic>> items,
    String? notes,
  });
}
