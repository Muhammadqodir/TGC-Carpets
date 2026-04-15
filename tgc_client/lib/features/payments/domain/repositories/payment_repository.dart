import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/payment_entity.dart';

abstract class PaymentRepository {
  Future<Either<Failure, PaginatedResponse<PaymentEntity>>> getPayments({
    int? clientId,
    int? orderId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  });

  Future<Either<Failure, PaymentEntity>> createPayment({
    required int clientId,
    int? orderId,
    required double amount,
    String? notes,
  });

  Future<Either<Failure, void>> deletePayment(int id);
}
