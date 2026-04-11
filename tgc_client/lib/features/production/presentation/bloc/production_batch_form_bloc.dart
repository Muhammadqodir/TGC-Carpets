import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/create_production_batch_usecase.dart';
import '../../domain/usecases/update_production_batch_usecase.dart';
import 'production_batch_form_event.dart';
import 'production_batch_form_state.dart';

class ProductionBatchFormBloc
    extends Bloc<ProductionBatchFormEvent, ProductionBatchFormState> {
  final CreateProductionBatchUseCase createProductionBatchUseCase;
  final UpdateProductionBatchUseCase updateProductionBatchUseCase;

  ProductionBatchFormBloc({
    required this.createProductionBatchUseCase,
    required this.updateProductionBatchUseCase,
  }) : super(const ProductionBatchFormInitial()) {
    on<ProductionBatchFormSubmitted>(_onSubmitted);
    on<ProductionBatchFormUpdateSubmitted>(_onUpdateSubmitted);
  }

  Future<void> _onSubmitted(
    ProductionBatchFormSubmitted event,
    Emitter<ProductionBatchFormState> emit,
  ) async {
    emit(const ProductionBatchFormSubmitting());
    final result = await createProductionBatchUseCase(
      batchTitle:      event.batchTitle,
      machineId:       event.machineId,
      plannedDatetime: event.plannedDatetime,
      type:            event.type,
      notes:           event.notes,
      items:           event.items,
    );
    result.fold(
      (failure) => emit(ProductionBatchFormFailure(failure.message)),
      (batch)   => emit(ProductionBatchFormSuccess(batch)),
    );
  }

  Future<void> _onUpdateSubmitted(
    ProductionBatchFormUpdateSubmitted event,
    Emitter<ProductionBatchFormState> emit,
  ) async {
    emit(const ProductionBatchFormSubmitting());
    final result = await updateProductionBatchUseCase(
      event.batchId,
      batchTitle:      event.batchTitle,
      machineId:       event.machineId,
      plannedDatetime: event.plannedDatetime,
      type:            event.type,
      notes:           event.notes,
      items:           event.items,
    );
    result.fold(
      (failure) => emit(ProductionBatchFormFailure(failure.message)),
      (batch)   => emit(ProductionBatchFormSuccess(batch)),
    );
  }
}
