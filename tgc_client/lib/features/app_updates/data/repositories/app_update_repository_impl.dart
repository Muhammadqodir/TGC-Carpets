import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_release_entity.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../datasources/app_update_remote_datasource.dart';

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  final AppUpdateRemoteDataSource remoteDataSource;

  const AppUpdateRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, AppReleaseEntity?>> getLatestRelease({
    required String platform,
  }) async {
    try {
      final release = await remoteDataSource.getLatestRelease(platform: platform);
      return Right(release);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
