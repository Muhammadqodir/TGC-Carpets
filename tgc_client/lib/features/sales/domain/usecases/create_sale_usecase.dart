import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/sale_entity.dart';
import '../repositories/sale_repository.dart';

class CreateSaleUseCase {
  final SaleRepository _repository;

  const CreateSaleUseCase(this._repository);

  Future<Either<Failure, SaleEntity>> call({
    required int clientId,
    required String saleDate,
    required String paymentStatus,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) =>
      _repository.createSale(
        clientId: clientId,
        saleDate: saleDate,
        paymentStatus: paymentStatus,
        items: items,
        notes: notes,
      );
}
