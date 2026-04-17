import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_client_debit_ledger_usecase.dart';
import 'debit_ledger_event.dart';
import 'debit_ledger_state.dart';

class DebitLedgerBloc extends Bloc<DebitLedgerEvent, DebitLedgerState> {
  final GetClientDebitLedgerUseCase getClientDebitLedgerUseCase;

  DebitLedgerBloc({required this.getClientDebitLedgerUseCase})
      : super(const DebitLedgerInitial()) {
    on<DebitLedgerLoadRequested>(_onLoad);
    on<DebitLedgerRefreshRequested>(_onRefresh);
  }

  Future<void> _onLoad(
    DebitLedgerLoadRequested event,
    Emitter<DebitLedgerState> emit,
  ) async {
    emit(const DebitLedgerLoading());
    await _fetch(emit, event.clientId);
  }

  Future<void> _onRefresh(
    DebitLedgerRefreshRequested event,
    Emitter<DebitLedgerState> emit,
  ) async {
    emit(const DebitLedgerLoading());
    await _fetch(emit, event.clientId);
  }

  Future<void> _fetch(Emitter<DebitLedgerState> emit, int clientId) async {
    final result = await getClientDebitLedgerUseCase(clientId);
    result.fold(
      (failure) => emit(DebitLedgerError(failure.message)),
      (data)    => emit(DebitLedgerLoaded(data)),
    );
  }
}
