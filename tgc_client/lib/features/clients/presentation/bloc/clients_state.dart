import 'package:equatable/equatable.dart';
import '../../domain/entities/client_entity.dart';

abstract class ClientsState extends Equatable {
  const ClientsState();

  @override
  List<Object?> get props => [];
}

// ─── Action status ──────────────────────────────────────────────────────────

sealed class ClientActionStatus extends Equatable {
  const ClientActionStatus();
}

class ClientActionIdle extends ClientActionStatus {
  const ClientActionIdle();
  @override
  List<Object?> get props => [];
}

class ClientActionPending extends ClientActionStatus {
  final int clientId;
  const ClientActionPending(this.clientId);
  @override
  List<Object?> get props => [clientId];
}

class ClientActionSuccess extends ClientActionStatus {
  final String message;
  const ClientActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class ClientActionFailure extends ClientActionStatus {
  final String message;
  const ClientActionFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// ─── Page states ─────────────────────────────────────────────────────────────

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
  final int total;
  final ClientActionStatus actionStatus;

  const ClientsLoaded({
    required this.clients,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    required this.total,
    this.actionStatus = const ClientActionIdle(),
  });

  ClientsLoaded copyWith({
    List<ClientEntity>? clients,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    int? total,
    ClientActionStatus? actionStatus,
  }) =>
      ClientsLoaded(
        clients: clients ?? this.clients,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        total: total ?? this.total,
        actionStatus: actionStatus ?? this.actionStatus,
      );

  @override
  List<Object?> get props =>
      [clients, hasNextPage, isLoadingMore, currentPage, total, actionStatus];
}

class ClientsError extends ClientsState {
  final String message;

  const ClientsError(this.message);

  @override
  List<Object?> get props => [message];
}
