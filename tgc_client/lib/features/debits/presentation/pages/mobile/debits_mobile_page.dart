import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/client_debit_entity.dart';
import '../../bloc/debits_bloc.dart';
import '../../bloc/debits_event.dart';
import '../../bloc/debits_state.dart';

/// Mobile card-list view for the Debits feature.
class DebitsMobilePage extends StatefulWidget {
  const DebitsMobilePage({super.key});

  @override
  State<DebitsMobilePage> createState() => _DebitsMobilePageState();
}

class _DebitsMobilePageState extends State<DebitsMobilePage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
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
    context.pushNamed(AppRoutes.clientDebitDetailName, extra: client);
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
        actions: [
          IconButton(
            onPressed: () => context
                .read<DebitsBloc>()
                .add(const DebitsRefreshRequested()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => _applyFilters(search: v),
                    decoration: const InputDecoration(
                      hintText: 'Do\'kon, ism...',
                      prefixIcon: Icon(Icons.search, size: 18),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Qarzdorlar'),
                  selected: _hasBalance,
                  onSelected: (v) => _applyFilters(hasBalance: v),
                ),
              ],
            ),
          ),

          // Content
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
                    return const Center(child: Text('Debitorlar topilmadi'));
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: state.clients.length +
                        (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == state.clients.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      return _ClientDebitCard(
                        client: state.clients[i],
                        onTap: () => _openDetail(state.clients[i]),
                      );
                    },
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

class _ClientDebitCard extends StatelessWidget {
  const _ClientDebitCard({required this.client, required this.onTap});

  final ClientDebitEntity client;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isInDebt = client.balance > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Text(
                      client.shopName ?? '—',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isInDebt ? AppColors.error : AppColors.success)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isInDebt ? 'Qarz' : 'Ortiqcha',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isInDebt
                            ? AppColors.error
                            : AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                client.contactName != null
                    ? '${client.contactName} • ${client.region ?? "—"}'
                    : client.region ?? '—',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              // Amounts row
              Row(
                children: [
                  _AmountTile(
                    label: 'Yuklama',
                    value: '-${client.totalDebit.toStringAsFixed(2)}',
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 12),
                  _AmountTile(
                    label: "To'lov",
                    value: '+${client.totalCredit.toStringAsFixed(2)}',
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 12),
                  _AmountTile(
                    label: 'Balans',
                    value: '${client.balance > 0 ? '-' : (client.balance < 0 ? '+' : '')}${client.balance.abs().toStringAsFixed(2)}',
                    color: isInDebt ? AppColors.error : AppColors.success,
                    bold: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  const _AmountTile({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
