import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/app_release_entity.dart';
import '../repositories/app_update_repository.dart';

/// Fetches the latest release from the server and returns it only when an
/// update is available (i.e. server build_code > [currentBuildCode]).
/// Returns [Right(null)] when the app is already up-to-date.
class CheckForUpdateUseCase {
  final AppUpdateRepository _repository;

  const CheckForUpdateUseCase(this._repository);

  Future<Either<Failure, AppReleaseEntity?>> call({
    required String platform,
    required int currentBuildCode,
  }) async {
    final result = await _repository.getLatestRelease(platform: platform);

    return result.fold(
      Left.new,
      (release) {
        if (release == null || release.buildCode <= currentBuildCode) {
          return const Right(null);
        }
        return Right(release);
      },
    );
  }
}
