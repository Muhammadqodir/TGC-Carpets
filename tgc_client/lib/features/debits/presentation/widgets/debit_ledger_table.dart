import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';

import '../../domain/entities/debit_ledger_entry_entity.dart';

String _fmtMoney(double v) => v.toStringAsFixed(2);

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.'
    '${d.year}';

/// Full chronological ledger for a single client showing shipment
/// debits, payment credits, and a running balance per row.
class DebitLedgerTable extends StatelessWidget {
  const DebitLedgerTable({
    super.key,
    required this.entries,
  });

  final List<DebitLedgerEntryEntity> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────
        _HeaderRow(theme: theme),
        const Divider(height: 1, color: AppColors.divider),

        // ── Rows ─────────────────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, i) =>
                _LedgerRow(entry: entries[i], theme: theme),
          ),
        ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.labelMedium?.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Sana',       style: style)),
          Expanded(flex: 1, child: Text('Tur',        style: style)),
          Expanded(flex: 3, child: Text('Ma\'lumoт',  style: style)),
          Expanded(flex: 2, child: Text('Debit (\$)',  style: style, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('Kredit (\$)', style: style, textAlign: TextAlign.right)),
          Expanded(flex: 2, child: Text('Balans (\$)', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.theme});

  final DebitLedgerEntryEntity entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isShipment = entry.isShipment;
    final rowColor   = isShipment
        ? AppColors.error.withOpacity(0.04)
        : AppColors.success.withOpacity(0.04);

    final balanceColor = entry.runningBalance > 0
        ? AppColors.error
        : entry.runningBalance < 0
            ? AppColors.success
            : AppColors.textSecondary;

    return Container(
      color: rowColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date
          Expanded(
            flex: 2,
            child: Text(
              _fmtDate(entry.date),
              style: theme.textTheme.bodyMedium,
            ),
          ),

          // Type badge
          Expanded(
            flex: 1,
            child: _TypeBadge(isShipment: isShipment),
          ),

          // Reference + notes
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.reference,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.notes!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Debit
          Expanded(
            flex: 2,
            child: Text(
              entry.debit > 0 ? _fmtMoney(entry.debit) : '—',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: entry.debit > 0 ? AppColors.error : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Credit
          Expanded(
            flex: 2,
            child: Text(
              entry.credit > 0 ? _fmtMoney(entry.credit) : '—',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: entry.credit > 0 ? AppColors.success : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),

          // Running balance
          Expanded(
            flex: 2,
            child: Text(
              _fmtMoney(entry.runningBalance),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: balanceColor,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isShipment});

  final bool isShipment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isShipment ? AppColors.error : AppColors.success)
            .withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isShipment ? 'Yuk' : "To'lov",
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isShipment ? AppColors.error : AppColors.success,
              fontWeight: FontWeight.w700,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
