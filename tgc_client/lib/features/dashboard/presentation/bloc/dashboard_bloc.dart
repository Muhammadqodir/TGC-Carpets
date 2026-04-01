import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_dashboard_stats_usecase.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final GetDashboardStatsUseCase getDashboardStatsUseCase;

  DashboardBloc({required this.getDashboardStatsUseCase})
      : super(DashboardInitial()) {
    on<DashboardStatsRequested>(_onStatsRequested);
  }

  Future<void> _onStatsRequested(
    DashboardStatsRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(DashboardLoading());

    final from = _fmt(event.from);
    final to = _fmt(event.to);

    final result = await getDashboardStatsUseCase(from: from, to: to);

    result.fold(
      (failure) => emit(DashboardError(failure.message)),
      (stats) => emit(DashboardStatsLoaded(stats)),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
