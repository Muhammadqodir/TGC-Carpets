import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';
import 'package:tgc_client/features/debits/presentation/bloc/debits_bloc.dart';
import 'package:tgc_client/features/debits/presentation/bloc/debits_event.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/client_debit_entity.dart';
import '../bloc/debit_ledger_bloc.dart';
import '../bloc/debit_ledger_event.dart';
import '../bloc/debit_ledger_state.dart';
import '../widgets/debit_ledger_table.dart';

/// Full-screen detail page for a single client's debit/credit ledger.
/// Receives [ClientDebitEntity] via GoRouter `extra`.
class ClientDebitDetailPage extends StatelessWidget {
  const ClientDebitDetailPage({super.key, required this.client});

  final ClientDebitEntity client;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<DebitLedgerBloc>()..add(DebitLedgerLoadRequested(client.id)),
      child: _ClientDebitDetailView(client: client),
    );
  }
}

class _ClientDebitDetailView extends StatelessWidget {
  const _ClientDebitDetailView({required this.client});

  final ClientDebitEntity client;

  void _addPayment(BuildContext context, ClientDebitEntity client) async {
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

    if (result == true && context.mounted) {
      context
          .read<DebitLedgerBloc>()
          .add(DebitLedgerRefreshRequested(client.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(client.shopName ?? '—'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          // Add payment shortcut
          FilledButton.icon(
            onPressed: () async {
              _addPayment(context, client);
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text("To'lov qo'shish"),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => context
                .read<DebitLedgerBloc>()
                .add(DebitLedgerRefreshRequested(client.id)),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yangilash',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: BlocBuilder<DebitLedgerBloc, DebitLedgerState>(
        builder: (context, state) {
          if (state is DebitLedgerLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DebitLedgerError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context
                        .read<DebitLedgerBloc>()
                        .add(DebitLedgerRefreshRequested(client.id)),
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          if (state is DebitLedgerLoaded) {
            final data = state.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Client info ─────────────────────────────────────────
                _ClientInfoBar(client: client),
                const Divider(height: 1, color: AppColors.divider),

                // ── Summary cards ───────────────────────────────────────
                _SummaryRow(
                  totalDebit: data.totalDebit,
                  totalCredit: data.totalCredit,
                  balance: data.balance,
                ),
                const Divider(height: 1, color: AppColors.divider),

                // ── Ledger table ────────────────────────────────────────
                if (data.entries.isEmpty)
                  const Expanded(
                    child: Center(child: Text('Harakatlar topilmadi')),
                  )
                else
                  Expanded(
                    child: DebitLedgerTable(entries: data.entries),
                  ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ── Summary row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.totalDebit,
    required this.totalCredit,
    required this.balance,
  });

  final double totalDebit;
  final double totalCredit;
  final double balance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      return Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Jami Yuklama',
                value: '-${totalDebit.toStringAsFixed(2)}',
                color: AppColors.error,
                icon: Icons.arrow_upward_rounded,
                isDesktop: isDesktop,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: "Jami To'lov",
                value: '+${totalCredit.toStringAsFixed(2)}',
                color: AppColors.success,
                icon: Icons.arrow_downward_rounded,
                isDesktop: isDesktop,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Joriy Balans',
                value:
                    '${balance > 0 ? '-' : (balance < 0 ? '+' : '')}${balance.abs().toStringAsFixed(2)}',
                color: balance >= 0 ? AppColors.error : AppColors.success,
                icon: balance >= 0
                    ? Icons.account_balance_wallet_outlined
                    : Icons.check_circle_outline_rounded,
                bold: true,
                isDesktop: isDesktop,
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    this.bold = false,
    this.isDesktop = false,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final bool bold;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          if (isDesktop) ...[
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Client info bar ──────────────────────────────────────────────────────────

class _ClientInfoBar extends StatelessWidget {
  const _ClientInfoBar({required this.client});

  final ClientDebitEntity client;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.store_outlined, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            client.shopName ?? '—',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 16),
          if (client.contactName != null) ...[
            Icon(Icons.person_outline,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(client.contactName!, style: theme.textTheme.bodyMedium),
            const SizedBox(width: 16),
          ],
          if (client.phone != null) ...[
            Icon(Icons.phone_outlined,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(client.phone!, style: theme.textTheme.bodyMedium),
            const SizedBox(width: 16),
          ],
          Icon(Icons.location_on_outlined,
              size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(client.region ?? '—', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
