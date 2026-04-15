import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/payment_repository.dart';

class DeletePaymentUseCase {
  final PaymentRepository _repository;

  const DeletePaymentUseCase(this._repository);

  Future<Either<Failure, void>> call(int id) =>
      _repository.deletePayment(id);
}
