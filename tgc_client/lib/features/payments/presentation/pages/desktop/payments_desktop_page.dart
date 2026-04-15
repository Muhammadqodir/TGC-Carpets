import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/dialogs/confirm_dialog.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_bloc.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_event.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_state.dart';

import '../../bloc/payments_bloc.dart';
import '../../bloc/payments_event.dart';
import '../../bloc/payments_state.dart';
import '../../widgets/payment_filter_bar.dart';
import '../../widgets/payment_table.dart';
import '../../../domain/entities/payment_entity.dart';
import '../../../../clients/domain/entities/client_entity.dart' show ClientEntity;

/// Desktop layout for the Payments page.
class PaymentsDesktopPage extends StatefulWidget {
  const PaymentsDesktopPage({super.key});

  @override
  State<PaymentsDesktopPage> createState() => _PaymentsDesktopPageState();
}

class _PaymentsDesktopPageState extends State<PaymentsDesktopPage> {
  final _scrollController = ScrollController();

  int? _selectedClientId;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<PaymentsBloc>().add(const PaymentsNextPageRequested());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilters({int? clientId, DateTimeRange? dateRange}) {
    setState(() {
      _selectedClientId = clientId;
      _selectedDateRange = dateRange;
    });
    context.read<PaymentsBloc>().add(
          PaymentsFiltersChanged(
            clientId: clientId,
            dateRange: dateRange,
          ),
        );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PaymentEntity payment,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: "To'lovni o'chirish",
      content:
          '#${payment.id} — \$${payment.amount.toStringAsFixed(2)} ni o\'chirishni tasdiqlaysizmi?',
      confirmText: "O'chirish",
      cancelText: 'Bekor qilish',
    );
    if (confirmed == true && context.mounted) {
      context.read<PaymentsBloc>().add(PaymentDeleted(payment.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ClientsBloc>()..add(const ClientsLoadRequested()),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("To'lovlar"),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
          actions: [
            FilledButton.icon(
              onPressed: () async {
                final result =
                    await context.pushNamed(AppRoutes.addPaymentName);
                if (result == true && context.mounted) {
                  context
                      .read<PaymentsBloc>()
                      .add(const PaymentsRefreshRequested());
                }
              },
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("To'lov qo'shish"),
            ),
            const SizedBox(width: 16),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter bar
            BlocBuilder<ClientsBloc, ClientsState>(
              builder: (context, clientsState) {
                final clients = clientsState is ClientsLoaded
                    ? clientsState.clients
                    : const <ClientEntity>[];
                return PaymentFilterBar(
                  clients: clients,
                  selectedClientId: _selectedClientId,
                  selectedDateRange: _selectedDateRange,
                  onClientChanged: (v) => _applyFilters(
                    clientId: v,
                    dateRange: _selectedDateRange,
                  ),
                  onDateRangeChanged: (v) => _applyFilters(
                    clientId: _selectedClientId,
                    dateRange: v,
                  ),
                  onRefresh: () => context
                      .read<PaymentsBloc>()
                      .add(const PaymentsRefreshRequested()),
                );
              },
            ),
            const Divider(height: 1, color: AppColors.divider),

            // Content
            Expanded(
              child: BlocBuilder<PaymentsBloc, PaymentsState>(
                builder: (context, state) {
                  if (state is PaymentsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is PaymentsError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.message, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context
                                .read<PaymentsBloc>()
                                .add(const PaymentsLoadRequested()),
                            child: const Text('Qayta urinish'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is PaymentsLoaded) {
                    if (state.payments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(
                              icon: HugeIcons.strokeRoundedMoney01,
                              size: 56,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "To'lovlar topilmadi",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      );
                    }

                    return PaymentTable(
                      payments: state.payments,
                      isLoadingMore: state.isLoadingMore,
                      scrollController: _scrollController,
                      onDelete: (p) => _confirmDelete(context, p),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
