import 'package:equatable/equatable.dart';
import '../../domain/entities/client_entity.dart';

abstract class ClientsState extends Equatable {
  const ClientsState();

  @override
  List<Object?> get props => [];
}

class ClientsInitial extends ClientsState {
  const ClientsInitial();
}

class ClientsLoading extends ClientsState {
  const ClientsLoading();
}

class ClientsLoaded extends ClientsState {
  final List<ClientEntity> clients;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;

  const ClientsLoaded({
    required this.clients,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
  });

  ClientsLoaded copyWith({
    List<ClientEntity>? clients,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
  }) =>
      ClientsLoaded(
        clients: clients ?? this.clients,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
      );

  @override
  List<Object?> get props => [clients, hasNextPage, isLoadingMore, currentPage];
}

class ClientsError extends ClientsState {
  final String message;

  const ClientsError(this.message);

  @override
  List<Object?> get props => [message];
}
