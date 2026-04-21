import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../entities/raw_material_entity.dart';
import '../entities/raw_material_movement_entity.dart';

abstract class RawMaterialRepository {
  // ── Materials ──────────────────────────────────────────────────────────────
  Future<Either<Failure, PaginatedResponse<RawMaterialEntity>>> getMaterials({
    String? type,
    String? search,
    int page = 1,
    int perPage = 50,
  });

  Future<Either<Failure, RawMaterialEntity>> createMaterial({
    required String name,
    required String type,
    required String unit,
  });

  Future<Either<Failure, void>> deleteMaterial(int id);

  // ── Movements ──────────────────────────────────────────────────────────────
  Future<Either<Failure, List<RawMaterialMovementEntity>>> storeBatchMovement({
    required String dateTime,
    required String type,
    String? notes,
    required List<Map<String, dynamic>> items,
  });
}
