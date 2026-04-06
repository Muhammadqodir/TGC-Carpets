import 'package:equatable/equatable.dart';

abstract class ClientsEvent extends Equatable {
  const ClientsEvent();

  @override
  List<Object?> get props => [];
}

class ClientsLoadRequested extends ClientsEvent {
  const ClientsLoadRequested();
}

class ClientsSearchChanged extends ClientsEvent {
  final String query;

  const ClientsSearchChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class ClientsNextPageRequested extends ClientsEvent {
  const ClientsNextPageRequested();
}

class ClientsRefreshRequested extends ClientsEvent {
  const ClientsRefreshRequested();
}

class ClientDeleteRequested extends ClientsEvent {
  final int clientId;

  const ClientDeleteRequested(this.clientId);

  @override
  List<Object?> get props => [clientId];
}
