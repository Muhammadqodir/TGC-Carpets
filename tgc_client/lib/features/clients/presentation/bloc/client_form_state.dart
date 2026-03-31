import 'package:equatable/equatable.dart';
import '../../domain/entities/client_entity.dart';

abstract class ClientFormState extends Equatable {
  const ClientFormState();

  @override
  List<Object?> get props => [];
}

class ClientFormInitial extends ClientFormState {
  const ClientFormInitial();
}

class ClientFormSubmitting extends ClientFormState {
  const ClientFormSubmitting();
}

class ClientFormSuccess extends ClientFormState {
  final ClientEntity client;

  const ClientFormSuccess(this.client);

  @override
  List<Object?> get props => [client];
}

class ClientFormFailure extends ClientFormState {
  final String message;

  const ClientFormFailure(this.message);

  @override
  List<Object?> get props => [message];
}
