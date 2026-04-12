import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/labeling_item_entity.dart';

abstract class LabelingRepository {
  Future<Either<Failure, List<LabelingItemEntity>>> getLabelingItems();

  Future<Either<Failure, LabelingItemEntity>> printLabel({
    required int batchId,
    required int itemId,
  });
}
