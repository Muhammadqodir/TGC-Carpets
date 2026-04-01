import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/dashboard_stats_entity.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardStatsUseCase {
  final DashboardRepository repository;

  const GetDashboardStatsUseCase(this.repository);

  Future<Either<Failure, DashboardStatsEntity>> call({
    required String from,
    required String to,
  }) =>
      repository.getStats(from: from, to: to);
}
