import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/store_batch_movement_usecase.dart';
import 'batch_movement_event.dart';
import 'batch_movement_state.dart';

class BatchMovementBloc extends Bloc<BatchMovementEvent, BatchMovementState> {
  final StoreBatchMovementUseCase storeBatchMovementUseCase;

  BatchMovementBloc({required this.storeBatchMovementUseCase})
      : super(const BatchMovementInitial()) {
    on<BatchMovementSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    BatchMovementSubmitted event,
    Emitter<BatchMovementState> emit,
  ) async {
    emit(const BatchMovementLoading());

    final result = await storeBatchMovementUseCase(
      dateTime: event.dateTime,
      type:     event.type,
      notes:    event.notes,
      items:    event.items,
    );

    result.fold(
      (failure) => emit(BatchMovementError(failure.message)),
      (_) => emit(const BatchMovementSuccess()),
    );
  }
}
