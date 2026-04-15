import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/payment_entity.dart';

abstract class PaymentsState extends Equatable {
  const PaymentsState();

  @override
  List<Object?> get props => [];
}

class PaymentsInitial extends PaymentsState {
  const PaymentsInitial();
}

class PaymentsLoading extends PaymentsState {
  const PaymentsLoading();
}

class PaymentsLoaded extends PaymentsState {
  final List<PaymentEntity> payments;
  final bool hasNextPage;
  final bool isLoadingMore;
  final int currentPage;
  final int? activeClientId;
  final DateTimeRange? activeDateRange;

  const PaymentsLoaded({
    required this.payments,
    required this.hasNextPage,
    this.isLoadingMore = false,
    required this.currentPage,
    this.activeClientId,
    this.activeDateRange,
  });

  PaymentsLoaded copyWith({
    List<PaymentEntity>? payments,
    bool? hasNextPage,
    bool? isLoadingMore,
    int? currentPage,
    int? activeClientId,
    DateTimeRange? activeDateRange,
    bool clearClientId = false,
    bool clearDateRange = false,
  }) =>
      PaymentsLoaded(
        payments: payments ?? this.payments,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        currentPage: currentPage ?? this.currentPage,
        activeClientId:
            clearClientId ? null : (activeClientId ?? this.activeClientId),
        activeDateRange:
            clearDateRange ? null : (activeDateRange ?? this.activeDateRange),
      );

  @override
  List<Object?> get props => [
        payments,
        hasNextPage,
        isLoadingMore,
        currentPage,
        activeClientId,
        activeDateRange,
      ];
}

class PaymentsError extends PaymentsState {
  final String message;
  const PaymentsError(this.message);

  @override
  List<Object?> get props => [message];
}
