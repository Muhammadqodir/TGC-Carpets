import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/raw_material_entity.dart';
import '../repositories/raw_material_repository.dart';

class GetRawMaterialsUseCase {
  final RawMaterialRepository repository;

  const GetRawMaterialsUseCase(this.repository);

  Future<Either<Failure, PaginatedResponse<RawMaterialEntity>>> call({
    String? type,
    String? search,
    int page = 1,
    int perPage = 50,
  }) =>
      repository.getMaterials(
        type: type,
        search: search,
        page: page,
        perPage: perPage,
      );
}
