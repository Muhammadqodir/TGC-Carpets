import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/create_order_usecase.dart';
import '../../domain/usecases/update_order_usecase.dart';
import 'order_form_event.dart';
import 'order_form_state.dart';

class OrderFormBloc extends Bloc<OrderFormEvent, OrderFormState> {
  final CreateOrderUseCase createOrderUseCase;
  final UpdateOrderUseCase updateOrderUseCase;

  OrderFormBloc({
    required this.createOrderUseCase,
    required this.updateOrderUseCase,
  }) : super(const OrderFormInitial()) {
    on<OrderFormSubmitted>(_onSubmitted);
    on<OrderFormUpdateSubmitted>(_onUpdateSubmitted);
  }

  Future<void> _onSubmitted(
    OrderFormSubmitted event,
    Emitter<OrderFormState> emit,
  ) async {
    emit(const OrderFormSubmitting());

    final result = await createOrderUseCase(
      orderDate: event.orderDate,
      items: event.items,
      clientId: event.clientId,
      notes: event.notes,
      externalUuid: event.externalUuid,
    );

    result.fold(
      (failure) => emit(OrderFormFailure(failure.message)),
      (order) => emit(OrderFormSuccess(order)),
    );
  }

  Future<void> _onUpdateSubmitted(
    OrderFormUpdateSubmitted event,
    Emitter<OrderFormState> emit,
  ) async {
    emit(const OrderFormSubmitting());

    final result = await updateOrderUseCase(
      event.orderId,
      orderDate: event.orderDate,
      items: event.items,
      clientId: event.clientId,
      notes: event.notes,
    );

    result.fold(
      (failure) => emit(OrderFormFailure(failure.message)),
      (order) => emit(OrderFormSuccess(order)),
    );
  }
}
