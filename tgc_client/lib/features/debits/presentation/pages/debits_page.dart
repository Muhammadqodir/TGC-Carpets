import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/desktop_status_bar.dart';
import 'package:tgc_client/core/ui/widgets/filter_bar.dart';
import 'package:tgc_client/core/ui/widgets/filter_search_field.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';
import 'package:tgc_client/features/debits/domain/entities/client_debit_entity.dart';
import 'package:tgc_client/features/debits/presentation/bloc/debits_bloc.dart';
import 'package:tgc_client/features/debits/presentation/bloc/debits_event.dart';
import 'package:tgc_client/features/debits/presentation/bloc/debits_state.dart';
import 'package:tgc_client/features/debits/presentation/widgets/debit_summary_table.dart';

/// Unified Debits page with adaptive table and status bar.
class DebitsPage extends StatelessWidget {
  const DebitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DebitsBloc>()..add(const DebitsLoadRequested()),
      child: const _DebitsView(),
    );
  }
}

// ---------------------------------------------------------------------------

class _DebitsView extends StatefulWidget {
  const _DebitsView();

  @override
  State<_DebitsView> createState() => _DebitsViewState();
}

class _DebitsViewState extends State<_DebitsView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _hasBalance = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<DebitsBloc>().add(const DebitsNextPageRequested());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilters({String? search, bool? hasBalance}) {
    setState(() {
      if (hasBalance != null) _hasBalance = hasBalance;
    });
    context.read<DebitsBloc>().add(
          DebitsFiltersChanged(
            search: search ?? _searchController.text.trim(),
            hasBalance: hasBalance ?? _hasBalance,
          ),
        );
  }

  void _openDetail(ClientDebitEntity client) {
    context.pushNamed(
      AppRoutes.clientDebitDetailName,
      extra: client,
    );
  }

  void _addPayment(ClientDebitEntity client) async {
    // Convert ClientDebitEntity to ClientEntity for AddPaymentPage
    final clientEntity = ClientEntity(
      id: client.id,
      uuid: client.uuid ?? '',
      shopName: client.shopName ?? '',
      contactName: client.contactName,
      phone: client.phone,
      region: client.region ?? '',
      address: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await context.pushNamed<bool>(
      AppRoutes.addPaymentName,
      extra: clientEntity,
    );

    if (result == true && mounted) {
      context.read<DebitsBloc>().add(const DebitsRefreshRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Debitorlar'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Filter bar ----
          FilterBar(
            filters: [
              FilterSearchField(
                controller: _searchController,
                onChanged: (v) => _applyFilters(search: v),
                hint: 'Do\'kon, ism yoki telefon...',
                width: 280,
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Qarzdorlar'),
                selected: _hasBalance,
                onSelected: (v) => _applyFilters(hasBalance: v),
              ),
            ],
            onRefresh: () =>
                context.read<DebitsBloc>().add(const DebitsRefreshRequested()),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ---- Table / states ----
          Expanded(
            child: BlocBuilder<DebitsBloc, DebitsState>(
              builder: (context, state) {
                if (state is DebitsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is DebitsError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context
                              .read<DebitsBloc>()
                              .add(const DebitsLoadRequested()),
                          child: const Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is DebitsLoaded) {
                  if (state.clients.isEmpty) {
                    return const Center(
                      child: Text('Debitorlar topilmadi'),
                    );
                  }

                  return DebitSummaryTable(
                    clients: state.clients,
                    isLoadingMore: state.isLoadingMore,
                    scrollController: _scrollController,
                    onViewDetails: _openDetail,
                    onAddPayment: _addPayment,
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ---- Status bar with totals ----
          BlocBuilder<DebitsBloc, DebitsState>(builder: (context, state) {
            if (state is! DebitsLoaded) {
              return const DesktopStatusBar(child: SizedBox.shrink());
            }

            final loaded = state.clients.length;
            final hasMore = state.hasNextPage;
            final totalDebit = state.clients.fold(0.0, (s, c) => s + c.totalDebit);
            final totalCredit =
                state.clients.fold(0.0, (s, c) => s + c.totalCredit);
            final balance = totalDebit - totalCredit;

            return DesktopStatusBar(
              child: Row(
                children: [
                  Text(
                    '$loaded ta debitor${hasMore ? ' (yana mavjud)' : ''}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    'Yuklama: ',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Text(
                    '-${totalDebit.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    "To'lov: ",
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Text(
                    '+${totalCredit.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Balans: ',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Text(
                    '${balance > 0 ? '-' : (balance < 0 ? '+' : '')}${balance.abs().toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: balance >= 0 ? AppColors.error : AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
