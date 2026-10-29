import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/label_print_result.dart';
import '../entities/labeling_item_entity.dart';

abstract class LabelingRepository {
  Future<Either<Failure, List<LabelingItemEntity>>> getLabelingItems();

  /// Records one physical label. [printedAt] is when it came out of the
  /// printer: the print queue can send it much later.
  Future<Either<Failure, LabelPrintResult>> printLabel({
    required int batchId,
    required int itemId,
    required String idempotencyKey,
    bool reprint = false,
    DateTime? printedAt,
  });

  /// The subset of [keys] the server has on record.
  Future<Either<Failure, Set<String>>> verifyPrintedLabels(List<String> keys);
}
