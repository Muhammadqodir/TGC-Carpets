import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/order_entity.dart';
import '../../domain/usecases/get_order_usecase.dart';

abstract class OrderDetailState extends Equatable {
  const OrderDetailState();

  @override
  List<Object?> get props => [];
}

class OrderDetailInitial extends OrderDetailState {
  const OrderDetailInitial();
}

class OrderDetailLoading extends OrderDetailState {
  const OrderDetailLoading();
}

class OrderDetailLoaded extends OrderDetailState {
  final OrderEntity order;

  const OrderDetailLoaded(this.order);

  @override
  List<Object?> get props => [order];
}

class OrderDetailError extends OrderDetailState {
  final String message;

  const OrderDetailError(this.message);

  @override
  List<Object?> get props => [message];
}

class OrderDetailCubit extends Cubit<OrderDetailState> {
  final GetOrderUseCase _getOrder;

  OrderDetailCubit(this._getOrder) : super(const OrderDetailInitial());

  Future<void> load(int id) async {
    emit(const OrderDetailLoading());
    final result = await _getOrder(id);
    result.fold(
      (failure) => emit(OrderDetailError(failure.message)),
      (order) => emit(OrderDetailLoaded(order)),
    );
  }
}
