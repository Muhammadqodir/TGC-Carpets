import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/pages/pdf_viewer.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';

import '../../domain/entities/debit_ledger_entry_entity.dart';

String _fmtMoney(double v) => v.toStringAsFixed(2);

/// Formats a running balance with sign:
/// positive = client owes → '-', negative = client in credit → '+'.
String _fmtBalance(double v) {
  if (v == 0) return '0.00';
  final sign = v > 0 ? '-' : '+';
  return '$sign${v.abs().toStringAsFixed(2)}';
}

String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.'
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

        // ── Rows (newest first) ──────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, i) => _LedgerRow(
                entry: entries[entries.length - 1 - i], theme: theme),
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

    return LayoutBuilder(builder: (context, constraints) {
      bool isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      return Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (isDesktop) ...[
              Expanded(flex: 2, child: Text('Sana', style: style)),
              Expanded(flex: 1, child: Text('Tur', style: style)),
              Expanded(flex: 3, child: Text('Ma\'lumot', style: style)),
              Expanded(
                  flex: 2,
                  child: Text('Yuklama (\$)',
                      style: style, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('To\'lov (\$)',
                      style: style, textAlign: TextAlign.right)),
            ] else ...[
              Expanded(flex: 3, child: Text('Ma\'lumot', style: style)),
              Expanded(
                  flex: 2,
                  child: Text('Yuklama / To\'lov',
                      style: style, textAlign: TextAlign.right)),
            ],
            Expanded(
                flex: 2,
                child:
                    Text('Balans', style: style, textAlign: TextAlign.right)),
          ],
        ),
      );
    });
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.theme});

  final DebitLedgerEntryEntity entry;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isShipment = entry.isShipment;
    final rowColor = isShipment
        ? AppColors.error.withOpacity(0.04)
        : AppColors.success.withOpacity(0.04);

    final balanceColor = entry.runningBalance > 0
        ? AppColors.error
        : entry.runningBalance < 0
            ? AppColors.success
            : AppColors.textSecondary;

    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      return Container(
        color: rowColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isDesktop) ...[
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
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        // padding: EdgeInsets.zero,
                        // minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedPdf01,
                        size: 16,
                      ),
                      label: Text(
                        entry.reference,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        if (isShipment) {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => PdfViewerPage(
                                pdfUrl: entry.pdfUrl!,
                                title: entry.reference,
                              ),
                            ),
                          );
                        }
                      },
                    )
                  ],
                ),
              ),
              // Debit (shipment — shown with minus sign)
              Expanded(
                flex: 2,
                child: Text(
                  entry.debit > 0 ? '-${_fmtMoney(entry.debit)}' : '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: entry.debit > 0
                        ? AppColors.error
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),

              // Credit (payment — shown with plus sign)
              Expanded(
                flex: 2,
                child: Text(
                  entry.credit > 0 ? '+${_fmtMoney(entry.credit)}' : '—',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: entry.credit > 0
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ] else ...[
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypeBadge(isShipment: isShipment),
                        const SizedBox(width: 4),
                        Text(
                          _fmtDate(entry.date),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        // padding: EdgeInsets.zero,
                        // minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedPdf01,
                        size: 16,
                      ),
                      label: Text(
                        entry.reference,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () {
                        if (isShipment) {
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) => PdfViewerPage(
                                pdfUrl: entry.pdfUrl!,
                                title: entry.reference,
                              ),
                            ),
                          );
                        }
                      },
                    )
                  ],
                ),
              ),
              // Credit Debit
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      entry.credit > 0 ? '+${_fmtMoney(entry.credit)}' : '—',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: entry.credit > 0
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    Text(
                      entry.debit > 0 ? '-${_fmtMoney(entry.debit)}' : '—',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: entry.debit > 0
                            ? AppColors.error
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],

            // Running balance (- = owes, + = in credit)
            Expanded(
              flex: 2,
              child: Text(
                _fmtBalance(entry.runningBalance),
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
    });
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.isShipment});

  final bool isShipment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AppBadge(
          color: isShipment ? AppColors.error : AppColors.success,
          label: isShipment ? 'Yuklama' : "To'lov",
        )
      ],
    );
  }
}
