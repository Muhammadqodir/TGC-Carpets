import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/scanned_item_entity.dart';

abstract class ScannerRepository {
  Future<Either<Failure, ScannedItemEntity>> scanItem(String code);
}
