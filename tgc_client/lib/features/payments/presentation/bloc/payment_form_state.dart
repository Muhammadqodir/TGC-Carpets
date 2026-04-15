import 'package:equatable/equatable.dart';

import '../../domain/entities/payment_entity.dart';

abstract class PaymentFormState extends Equatable {
  const PaymentFormState();

  @override
  List<Object?> get props => [];
}

class PaymentFormInitial extends PaymentFormState {
  const PaymentFormInitial();
}

class PaymentFormSubmitting extends PaymentFormState {
  const PaymentFormSubmitting();
}

class PaymentFormSuccess extends PaymentFormState {
  final PaymentEntity payment;
  const PaymentFormSuccess(this.payment);

  @override
  List<Object?> get props => [payment];
}

class PaymentFormFailure extends PaymentFormState {
  final String message;
  const PaymentFormFailure(this.message);

  @override
  List<Object?> get props => [message];
}
