import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/services/label_print_queue.dart';
import '../../domain/entities/labeling_item_entity.dart';
import '../../domain/repositories/labeling_repository.dart';
import 'labeling_event.dart';
import 'labeling_state.dart';

/// The labeling list as the operator sees it: the server's lines plus the
/// labels printed here that the server has not confirmed yet (see
/// [LabelPrintQueue]). Printing itself never waits for the network.
class LabelingBloc extends Bloc<LabelingEvent, LabelingState> {
  final LabelingRepository _repository;
  final LabelPrintQueue _queue;
  late final StreamSubscription<LabelPrintQueueUpdate> _queueSub;

  /// The lines as the server last reported them.
  List<LabelingItemEntity> _serverItems = const [];

  LabelingBloc({
    required LabelingRepository repository,
    required LabelPrintQueue queue,
  })  : _repository = repository,
        _queue = queue,
        super(const LabelingInitial()) {
    on<LabelingLoadRequested>(_onLoadRequested);
    on<LabelingRefreshRequested>(_onRefreshRequested);
    on<LabelingPrintStarted>(_onPrintStarted);
    on<LabelingPrintCompleted>(_onPrintCompleted);
    on<LabelingQueueChanged>(_onQueueChanged);

    _queueSub = _queue.updates.listen(
      (u) => add(LabelingQueueChanged(confirmedItem: u.confirmedItem)),
    );
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

  void _onPrintStarted(LabelingPrintStarted event, Emitter<LabelingState> emit) {
    final current = state;
    if (current is! LabelingLoaded) return;
    emit(current.copyWith(printingItems: {...current.printingItems, event.itemId: true}));
  }

  void _onPrintCompleted(LabelingPrintCompleted event, Emitter<LabelingState> emit) {
    final current = state;
    if (current is! LabelingLoaded) return;
    final printing = Map<int, bool>.from(current.printingItems)..remove(event.itemId);
    emit(current.copyWith(printingItems: printing));
  }

  /// A label was queued, printed, dropped or confirmed. A confirmation
  /// carries the server's counts for that line; only the counts are taken,
  /// the rest of the line stays as the list loaded it.
  void _onQueueChanged(LabelingQueueChanged event, Emitter<LabelingState> emit) {
    final confirmed = event.confirmedItem;
    if (confirmed != null) {
      _serverItems = _serverItems
          .map((i) => i.id == confirmed.id
              ? i.copyWith(
                  producedQuantity: confirmed.producedQuantity,
                  defectQuantity: confirmed.defectQuantity,
                )
              : i)
          .toList(growable: false);
    }
    final current = state;
    if (current is LabelingLoaded) {
      emit(_loaded(printingItems: current.printingItems));
    }
  }

  /// A label the server accepts while the list is in flight may or may not
  /// be in it, and is no longer counted locally: fetch once more so it is
  /// neither lost nor counted twice.
  Future<void> _fetchItems(Emitter<LabelingState> emit) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      final before = _queue.confirmations;
      final result = await _repository.getLabelingItems();
      final failure = result.fold((f) => f, (items) {
        _serverItems = items;
        return null;
      });
      if (failure != null) {
        emit(LabelingError(failure.message));
        return;
      }
      if (_queue.confirmations == before) break;
    }
    emit(_loaded());
  }

  LabelingLoaded _loaded({Map<int, bool> printingItems = const {}}) {
    final items = _serverItems
        .map((i) {
          final local = _queue.localCountFor(i.id);
          return local == 0 ? i : i.copyWith(producedQuantity: i.producedQuantity + local);
        })
        .where((i) => !i.isFullyLabeled)
        .toList(growable: false);
    return LabelingLoaded(items: items, printingItems: printingItems);
  }

  @override
  Future<void> close() async {
    await _queueSub.cancel();
    return super.close();
  }
}
