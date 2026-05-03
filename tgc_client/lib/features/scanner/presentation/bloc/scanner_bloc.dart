import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/scanner_repository.dart';
import 'scanner_event.dart';
import 'scanner_state.dart';

class ScannerBloc extends Bloc<ScannerEvent, ScannerState> {
  final ScannerRepository repository;

  ScannerBloc({required this.repository}) : super(const ScannerInitial()) {
    on<ScannerCodeScanned>(_onCodeScanned);
    on<ScannerResetRequested>(_onResetRequested);
  }

  Future<void> _onCodeScanned(
    ScannerCodeScanned event,
    Emitter<ScannerState> emit,
  ) async {
    emit(const ScannerScanning());

    final result = await repository.scanItem(event.code);

    result.fold(
      (failure) => emit(ScannerError(failure.message)),
      (item) => emit(ScannerLoaded(item)),
    );
  }

  void _onResetRequested(
    ScannerResetRequested event,
    Emitter<ScannerState> emit,
  ) {
    emit(const ScannerInitial());
  }
}
