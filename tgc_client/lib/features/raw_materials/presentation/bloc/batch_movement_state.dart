import 'package:equatable/equatable.dart';

abstract class BatchMovementState extends Equatable {
  const BatchMovementState();

  @override
  List<Object?> get props => [];
}

class BatchMovementInitial extends BatchMovementState {
  const BatchMovementInitial();
}

class BatchMovementLoading extends BatchMovementState {
  const BatchMovementLoading();
}

class BatchMovementSuccess extends BatchMovementState {
  const BatchMovementSuccess();
}

class BatchMovementError extends BatchMovementState {
  final String message;

  const BatchMovementError(this.message);

  @override
  List<Object?> get props => [message];
}
