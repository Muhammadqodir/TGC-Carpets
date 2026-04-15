import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/create_payment_usecase.dart';
import 'payment_form_event.dart';
import 'payment_form_state.dart';

class PaymentFormBloc extends Bloc<PaymentFormEvent, PaymentFormState> {
  final CreatePaymentUseCase createPaymentUseCase;

  PaymentFormBloc({required this.createPaymentUseCase})
      : super(const PaymentFormInitial()) {
    on<PaymentFormSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    PaymentFormSubmitted event,
    Emitter<PaymentFormState> emit,
  ) async {
    emit(const PaymentFormSubmitting());

    final result = await createPaymentUseCase(
      clientId: event.clientId,
      orderId: event.orderId,
      amount: event.amount,
      notes: event.notes,
    );

    result.fold(
      (failure) => emit(PaymentFormFailure(failure.message)),
      (payment) => emit(PaymentFormSuccess(payment)),
    );
  }
}
