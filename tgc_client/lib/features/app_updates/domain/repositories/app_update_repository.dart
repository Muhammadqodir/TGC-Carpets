import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/app_release_entity.dart';

abstract class AppUpdateRepository {
  /// Returns the latest release for [platform].
  /// Returns [null] (in Right) when the server has no release for that platform.
  Future<Either<Failure, AppReleaseEntity?>> getLatestRelease({
    required String platform,
  });
}
