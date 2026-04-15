import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/payment_entity.dart';
import '../repositories/payment_repository.dart';

class CreatePaymentUseCase {
  final PaymentRepository _repository;

  const CreatePaymentUseCase(this._repository);

  Future<Either<Failure, PaymentEntity>> call({
    required int clientId,
    int? orderId,
    required double amount,
    String? notes,
  }) =>
      _repository.createPayment(
        clientId: clientId,
        orderId: orderId,
        amount: amount,
        notes: notes,
      );
}
