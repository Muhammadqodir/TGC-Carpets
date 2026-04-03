import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/create_sale_usecase.dart';
import 'sale_form_event.dart';
import 'sale_form_state.dart';

class SaleFormBloc extends Bloc<SaleFormEvent, SaleFormState> {
  final CreateSaleUseCase createSaleUseCase;

  SaleFormBloc({required this.createSaleUseCase})
      : super(const SaleFormInitial()) {
    on<SaleFormSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    SaleFormSubmitted event,
    Emitter<SaleFormState> emit,
  ) async {
    emit(const SaleFormSubmitting());

    final result = await createSaleUseCase(
      clientId: event.clientId,
      saleDate: event.saleDate,
      items: event.items,
      notes: event.notes,
    );

    result.fold(
      (failure) => emit(SaleFormFailure(failure.message)),
      (sale) => emit(SaleFormSuccess(sale)),
    );
  }
}
