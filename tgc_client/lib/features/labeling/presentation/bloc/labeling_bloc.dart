import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/labeling_repository.dart';
import 'labeling_event.dart';
import 'labeling_state.dart';

class LabelingBloc extends Bloc<LabelingEvent, LabelingState> {
  final LabelingRepository _repository;

  LabelingBloc({required LabelingRepository repository})
      : _repository = repository,
        super(const LabelingInitial()) {
    on<LabelingLoadRequested>(_onLoadRequested);
    on<LabelingRefreshRequested>(_onRefreshRequested);
    on<LabelingPrintRequested>(_onPrintRequested);
  }

  Future<void> _onLoadRequested(
    LabelingLoadRequested event,
    Emitter<LabelingState> emit,
  ) async {
    emit(const LabelingLoading());
    await _fetchItems(emit);
  }

  Future<void> _onRefreshRequested(
    LabelingRefreshRequested event,
    Emitter<LabelingState> emit,
  ) async {
    emit(const LabelingLoading());
    await _fetchItems(emit);
  }

  Future<void> _onPrintRequested(
    LabelingPrintRequested event,
    Emitter<LabelingState> emit,
  ) async {
    final current = state;
    if (current is! LabelingLoaded) return;

    // Mark item as printing
    emit(current.copyWith(
      printingItems: {...current.printingItems, event.itemId: true},
    ));

    final result = await _repository.printLabel(
      batchId: event.batchId,
      itemId: event.itemId,
    );

    result.fold(
      (failure) {
        // Restore printing state without the failing item; surface error via SnackBar
        final updated = Map<int, bool>.from(current.printingItems)
          ..remove(event.itemId);
        emit(current.copyWith(printingItems: updated));
        emit(LabelingError(failure.message));
        emit(current.copyWith(printingItems: updated));
      },
      (updatedItem) {
        final updatedItems = current.items.map((item) {
          return item.id == updatedItem.id ? updatedItem : item;
        }).where((item) => !item.isFullyLabeled).toList();

        final updatedPrinting = Map<int, bool>.from(current.printingItems)
          ..remove(event.itemId);

        emit(LabelingLoaded(
          items: updatedItems,
          printingItems: updatedPrinting,
        ));
      },
    );
  }

  Future<void> _fetchItems(Emitter<LabelingState> emit) async {
    final result = await _repository.getLabelingItems();
    result.fold(
      (failure) => emit(LabelingError(failure.message)),
      (items) => emit(LabelingLoaded(items: items)),
    );
  }
}
