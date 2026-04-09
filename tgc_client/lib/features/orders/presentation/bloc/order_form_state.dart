import 'package:equatable/equatable.dart';

import '../../domain/entities/order_entity.dart';

abstract class OrderFormState extends Equatable {
  const OrderFormState();

  @override
  List<Object?> get props => [];
}

class OrderFormInitial extends OrderFormState {
  const OrderFormInitial();
}

class OrderFormSubmitting extends OrderFormState {
  const OrderFormSubmitting();
}

class OrderFormSuccess extends OrderFormState {
  final OrderEntity order;

  const OrderFormSuccess(this.order);

  @override
  List<Object?> get props => [order];
}

class OrderFormFailure extends OrderFormState {
  final String message;

  const OrderFormFailure(this.message);

  @override
  List<Object?> get props => [message];
}
