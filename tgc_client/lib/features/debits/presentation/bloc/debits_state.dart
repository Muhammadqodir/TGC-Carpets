import 'package:equatable/equatable.dart';

import '../../domain/entities/client_debit_entity.dart';

abstract class DebitsState extends Equatable {
  const DebitsState();

  @override
  List<Object?> get props => [];
}

class DebitsInitial extends DebitsState {
  const DebitsInitial();
}

class DebitsLoading extends DebitsState {
  const DebitsLoading();
}

class DebitsLoaded extends DebitsState {
  final List<ClientDebitEntity> clients;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;
  final String? activeSearch;
  final String? activeRegion;
  final bool activeHasBalance;

  const DebitsLoaded({
    required this.clients,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    this.activeSearch,
    this.activeRegion,
    this.activeHasBalance = false,
  });

  DebitsLoaded copyWith({
    List<ClientDebitEntity>? clients,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    String? activeSearch,
    String? activeRegion,
    bool? activeHasBalance,
    bool clearSearch = false,
    bool clearRegion = false,
  }) =>
      DebitsLoaded(
        clients:           clients ?? this.clients,
        hasNextPage:       hasNextPage ?? this.hasNextPage,
        isLoadingMore:     isLoadingMore ?? this.isLoadingMore,
        currentPage:       currentPage ?? this.currentPage,
        activeSearch:      clearSearch ? null : (activeSearch ?? this.activeSearch),
        activeRegion:      clearRegion ? null : (activeRegion ?? this.activeRegion),
        activeHasBalance:  activeHasBalance ?? this.activeHasBalance,
      );

  @override
  List<Object?> get props => [
        clients,
        hasNextPage,
        isLoadingMore,
        currentPage,
        activeSearch,
        activeRegion,
        activeHasBalance,
      ];
}

class DebitsError extends DebitsState {
  final String message;

  const DebitsError(this.message);

  @override
  List<Object?> get props => [message];
}
