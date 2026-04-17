import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/debits/domain/entities/client_debit_entity.dart';

import '../../bloc/debits_bloc.dart';
import '../../bloc/debits_event.dart';
import '../../bloc/debits_state.dart';
import '../../widgets/debit_summary_table.dart';

/// Desktop layout for the Debits overview page.
class DebitsDesktopPage extends StatefulWidget {
  const DebitsDesktopPage({super.key});

  @override
  State<DebitsDesktopPage> createState() => _DebitsDesktopPageState();
}

class _DebitsDesktopPageState extends State<DebitsDesktopPage> {
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
            search:     search ?? _searchController.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Debitorlar'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Filter bar ─────────────────────────────────────────────────
          _FilterBar(
            searchController: _searchController,
            hasBalance: _hasBalance,
            onSearchChanged: (v) => _applyFilters(search: v),
            onHasBalanceChanged: (v) => _applyFilters(hasBalance: v),
            onRefresh: () => context
                .read<DebitsBloc>()
                .add(const DebitsRefreshRequested()),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ── Totals bar ─────────────────────────────────────────────────
          BlocBuilder<DebitsBloc, DebitsState>(
            builder: (context, state) {
              if (state is DebitsLoaded) {
                return _TotalsBar(clients: state.clients);
              }
              return const SizedBox.shrink();
            },
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ── Table ──────────────────────────────────────────────────────
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
                    clients:          state.clients,
                    isLoadingMore:    state.isLoadingMore,
                    scrollController: _scrollController,
                    onRowTap:         _openDetail,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.hasBalance,
    required this.onSearchChanged,
    required this.onHasBalanceChanged,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final bool hasBalance;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onHasBalanceChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Search
          SizedBox(
            width: 280,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Do\'kon, ism yoki telefon...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Has balance filter
          FilterChip(
            label: const Text('Qarzdorlar'),
            selected: hasBalance,
            onSelected: onHasBalanceChanged,
          ),
          const Spacer(),

          // Refresh
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yangilash',
          ),
        ],
      ),
    );
  }
}

// ── Totals summary bar ───────────────────────────────────────────────────────

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.clients});

  final List<ClientDebitEntity> clients;

  static String _fmt(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final totalDebit  = clients.fold(0.0, (s, c) => s + c.totalDebit);
    final totalCredit = clients.fold(0.0, (s, c) => s + c.totalCredit);
    final balance     = totalDebit - totalCredit;

    final theme = Theme.of(context);

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${clients.length} ta mijoz',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const Spacer(),
          _SummaryChip(
            label: 'Jami Yuklama',
            value: '-${_fmt(totalDebit)}',
            color: AppColors.error,
          ),
          const SizedBox(width: 16),
          _SummaryChip(
            label: "Jami To'lov",
            value: '+${_fmt(totalCredit)}',
            color: AppColors.success,
          ),
          const SizedBox(width: 16),
          _SummaryChip(
            label: 'Jami Balans',
            value: '${balance > 0 ? '-' : (balance < 0 ? '+' : '')}${balance.abs().toStringAsFixed(2)}',
            color: balance >= 0 ? AppColors.error : AppColors.success,
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
