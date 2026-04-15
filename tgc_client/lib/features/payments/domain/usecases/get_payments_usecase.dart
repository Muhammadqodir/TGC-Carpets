import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/payment_entity.dart';
import '../repositories/payment_repository.dart';

class GetPaymentsUseCase {
  final PaymentRepository _repository;

  const GetPaymentsUseCase(this._repository);

  Future<Either<Failure, PaginatedResponse<PaymentEntity>>> call({
    int? clientId,
    int? orderId,
    String? dateFrom,
    String? dateTo,
    int page = 1,
    int perPage = 20,
  }) =>
      _repository.getPayments(
        clientId: clientId,
        orderId: orderId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: page,
        perPage: perPage,
      );
}
