import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/production_repository.dart';
import '../../domain/usecases/create_production_batch_usecase.dart';
import '../../domain/usecases/update_production_batch_usecase.dart';
import 'production_batch_form_event.dart';
import 'production_batch_form_state.dart';

class ProductionBatchFormBloc
    extends Bloc<ProductionBatchFormEvent, ProductionBatchFormState> {
  final CreateProductionBatchUseCase createProductionBatchUseCase;
  final UpdateProductionBatchUseCase updateProductionBatchUseCase;
  final ProductionRepository repository;

  ProductionBatchFormBloc({
    required this.createProductionBatchUseCase,
    required this.updateProductionBatchUseCase,
    required this.repository,
  }) : super(const ProductionBatchFormInitial()) {
    on<ProductionBatchFormSubmitted>(_onSubmitted);
    on<ProductionBatchFormUpdateSubmitted>(_onUpdateSubmitted);
    on<ProductionBatchStartRequested>(_onStartRequested);
    on<ProductionBatchCompleteRequested>(_onCompleteRequested);
    on<ProductionBatchCancelRequested>(_onCancelRequested);
    on<ProductionBatchItemUpdateRequested>(_onItemUpdateRequested);
    on<ProductionBatchLoadRequested>(_onLoadRequested);
  }

  Future<void> _onSubmitted(
    ProductionBatchFormSubmitted event,
    Emitter<ProductionBatchFormState> emit,
  ) async {
    emit(const ProductionBatchFormSubmitting());

    final result = await createProductionBatchUseCase(
      batchTitle: event.batchTitle,
      machineId: event.machineId,
      plannedDatetime: event.plannedDatetime,
      type: event.type,
      notes: event.notes,
      items: event.items,
    );

    result.fold(
      (failure) => emit(ProductionBatchFormFailure(failure.message)),
      (batch) => emit(ProductionBatchFormSuccess(batch)),
    );
  }

  Future<void> _onUpdateSubmitted(
    ProductionBatchFormUpdateSubmitted event,
    Emitter<ProductionBatchFormState> emit,
  ) async {
    emit(const ProductionBatchFormSubmitting());

    final result = await updateProductionBatchUseCase(
      event.batchId,
      batchTitle: event.batchTitle,
      machineId: event.machineId,
      plannedDatetime: event.plannedDatetime,
      type: event.type,
      notes: event.notes,
      items: event.items,
    );

    result.fold(
      (failure) => emit(ProductionBatchFormFailure(failure.message)),
      (batch) => emit(ProductionBatchFormSuccess(batch)),
    );
  }

  Future<void> _onStartRequested(
    ProductionBatchStartRequested event,
    Emitter<ProductionBatchFormState> emit,
  ) async {
    emit(const ProductionBatchFormSubmitting());

    final result = await repository.startProductionBatch(event.batchId);

    result.fold(
      (failure) => emit(ProductionBatchFormFailure(failure.message)),
      (batch) => emit(ProductionBatchFormSuccess(batch)),
    );
  }

  Future<void> _onCompleteRequested(
    ProductionBatchCompleteRequested event,
    Emitter<ProductionBatchFormState> emit,
  ) async {
    emit(const ProductionBatchFormSubmitting());

    final result = await repository.completeProductionBatch(event.batchId);

    result.fold(
      (failure) => emit(ProductionBatchFormFailure(failure.message)),
      (batch) => emit(ProductionBatchFormSuccess(batch)),
    );
  }

  Future<void> _onCancelRequested(
    ProductionBatchCancelRequested event,
    Emitter<ProductionBatchFormState> emit,
  ) async {
    emit(const ProductionBatchFormSubmitting());

    final result = await repository.cancelProductionBatch(event.batchId);

    result.fold(
      (failure) => emit(ProductionBatchFormFailure(failure.message)),
      (batch) => emit(ProductionBatchFormSuccess(batch)),
    );
  }

  Future<void> _onItemUpdateRequested(
    ProductionBatchItemUpdateRequested event,
    Emitter<ProductionBatchFormState> emit,
  ) async {
    final result = await repository.updateBatchItem(
      event.batchId,
      event.itemId,
      producedQuantity: event.producedQuantity,
      defectQuantity: event.defectQuantity,
      notes: event.notes,
    );

    result.fold(
      (failure) => emit(ProductionBatchFormFailure(failure.message)),
      (_) => emit(const ProductionBatchItemUpdated()),
    );
  }

  Future<void> _onLoadRequested(
    ProductionBatchLoadRequested event,
    Emitter<ProductionBatchFormState> emit,
  ) async {
    emit(const ProductionBatchFormSubmitting());

    final result = await repository.getProductionBatch(event.batchId);

    result.fold(
      (failure) => emit(ProductionBatchFormFailure(failure.message)),
      (batch) => emit(ProductionBatchLoaded(batch)),
    );
  }
}
