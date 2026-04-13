import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/create_warehouse_document_usecase.dart';
import 'warehouse_form_event.dart';
import 'warehouse_form_state.dart';

class WarehouseFormBloc extends Bloc<WarehouseFormEvent, WarehouseFormState> {
  final CreateWarehouseDocumentUseCase createWarehouseDocumentUseCase;

  WarehouseFormBloc({required this.createWarehouseDocumentUseCase})
      : super(const WarehouseFormInitial()) {
    on<WarehouseFormSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    WarehouseFormSubmitted event,
    Emitter<WarehouseFormState> emit,
  ) async {
    emit(const WarehouseFormSubmitting());

    final result = await createWarehouseDocumentUseCase(
      type: event.type,
      documentDate: event.documentDate,
      items: event.items,
      sourceType: event.sourceType,
      sourceId: event.sourceId,
      notes: event.notes,
    );

    result.fold(
      (failure) => emit(WarehouseFormFailure(failure.message)),
      (document) => emit(WarehouseFormSuccess(document)),
    );
  }
}
