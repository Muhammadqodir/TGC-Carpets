import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/dialogs/confirm_dialog.dart';
import '../../../../clients/domain/entities/client_entity.dart';
import '../../../../clients/presentation/bloc/clients_bloc.dart';
import '../../../../clients/presentation/bloc/clients_event.dart';
import '../../../../clients/presentation/bloc/clients_state.dart';
import '../../../domain/entities/payment_entity.dart';
import '../../bloc/payments_bloc.dart';
import '../../bloc/payments_event.dart';
import '../../bloc/payments_state.dart';

/// Mobile card-list view for the Payments feature.
class PaymentsMobilePage extends StatefulWidget {
  const PaymentsMobilePage({super.key});

  @override
  State<PaymentsMobilePage> createState() => _PaymentsMobilePageState();
}

class _PaymentsMobilePageState extends State<PaymentsMobilePage> {
  final _scrollController = ScrollController();

  int? _selectedClientId;
  DateTimeRange? _selectedDateRange;
  bool _filterVisible = false;

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
          PaymentsFiltersChanged(clientId: clientId, dateRange: dateRange),
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
          "#${payment.id} — \$${payment.amount.toStringAsFixed(2)} ni o'chirishni tasdiqlaysizmi?",
      confirmText: "O'chirish",
      cancelText: 'Bekor qilish',
    );
    if (confirmed == true && context.mounted) {
      context.read<PaymentsBloc>().add(PaymentDeleted(payment.id));
    }
  }

  bool get _hasActiveFilters =>
      _selectedClientId != null || _selectedDateRange != null;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => context.read<ClientsBloc>()..add(const ClientsLoadRequested()),
      child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text("To'lovlar"),
            titleSpacing: 0,
            leading: IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                strokeWidth: 2,
              ),
              onPressed: () => context.pop(),
            ),
            actions: [
              // Filter toggle
              Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    tooltip: 'Filtr',
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedFilter,
                      strokeWidth: 1.8,
                    ),
                    onPressed: () =>
                        setState(() => _filterVisible = !_filterVisible),
                  ),
                  if (_hasActiveFilters)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              // Add button
              IconButton(
                onPressed: () async {
                  final result =
                      await context.pushNamed(AppRoutes.addPaymentName);
                  if (result == true && context.mounted) {
                    context
                        .read<PaymentsBloc>()
                        .add(const PaymentsRefreshRequested());
                  }
                },
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Collapsible filter panel
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _filterVisible
                    ? _MobileFilterPanel(
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
                        onClear: () {
                          _applyFilters(clientId: null, dateRange: null);
                          setState(() => _filterVisible = false);
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              if (_filterVisible)
                const Divider(height: 1, color: AppColors.divider),

              // List
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
                            Text(state.message,
                                textAlign: TextAlign.center),
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
                                    ?.copyWith(
                                        color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () async => context
                            .read<PaymentsBloc>()
                            .add(const PaymentsRefreshRequested()),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          controller: _scrollController,
                          padding: const EdgeInsets.all(12),
                          itemCount: state.payments.length +
                              (state.isLoadingMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (index >= state.payments.length) {
                              return const Padding(
                                padding:
                                    EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            final payment = state.payments[index];
                            return _PaymentCard(
                              payment: payment,
                              onDelete: () =>
                                  _confirmDelete(context, payment),
                            );
                          },
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),

              // Total summary bar
              BlocBuilder<PaymentsBloc, PaymentsState>(
                builder: (context, state) {
                  if (state is! PaymentsLoaded || state.payments.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _TotalSummaryBar(payments: state.payments);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mobile filter panel ──────────────────────────────────────────────────────

class _MobileFilterPanel extends StatelessWidget {
  const _MobileFilterPanel({
    required this.selectedClientId,
    required this.selectedDateRange,
    required this.onClientChanged,
    required this.onDateRangeChanged,
    required this.onClear,
  });

  final int? selectedClientId;
  final DateTimeRange? selectedDateRange;
  final ValueChanged<int?> onClientChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientsBloc, ClientsState>(
      builder: (context, clientsState) {
        final clients =
            clientsState is ClientsLoaded ? clientsState.clients : <ClientEntity>[];

        return Container(
          color: AppColors.surface,
          padding:
              const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Client dropdown
              DropdownButtonFormField<int>(
                value: selectedClientId,
                decoration: const InputDecoration(
                  labelText: 'Mijoz',
                  isDense: true,
                ),
                hint: const Text('Barcha mijozlar'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Barcha mijozlar'),
                  ),
                  ...clients.map(
                    (c) => DropdownMenuItem<int>(
                      value: c.id,
                      child: Text(
                        c.shopName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: onClientChanged,
              ),
              const SizedBox(height: 10),

              // Date range
              OutlinedButton.icon(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  size: 16,
                  color: selectedDateRange != null
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                label: Text(
                  selectedDateRange != null
                      ? _formatDateRange(selectedDateRange!)
                      : 'Sanani tanlang',
                  style: TextStyle(
                    color: selectedDateRange != null
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate:
                        DateTime.now().add(const Duration(days: 1)),
                    initialDateRange: selectedDateRange,
                  );
                  if (picked != null) onDateRangeChanged(picked);
                },
              ),
              const SizedBox(height: 10),

              // Clear
              if (selectedClientId != null || selectedDateRange != null)
                TextButton.icon(
                  icon: const Icon(Icons.clear_rounded, size: 16),
                  label: const Text('Filtrlarni tozalash'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.error),
                  onPressed: onClear,
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDateRange(DateTimeRange range) {
    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    return '${fmt(range.start)} – ${fmt(range.end)}';
  }
}

// ── Payment card ─────────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.onDelete,
  });

  final PaymentEntity payment;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left — amount badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '\$${payment.amount.toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Middle — details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client
                  Text(
                    payment.clientShopName ?? '—',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (payment.clientRegion != null &&
                      payment.clientRegion!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      payment.clientRegion!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 6),

                  // Meta row: date + optional order link
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(payment.createdAt),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                      if (payment.orderId != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '#${payment.orderId}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Notes
                  if (payment.notes != null &&
                      payment.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      payment.notes!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Right — delete action
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: AppColors.error,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: "O'chirish",
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ── Bottom summary bar ───────────────────────────────────────────────────────

class _TotalSummaryBar extends StatelessWidget {
  const _TotalSummaryBar({required this.payments});

  final List<PaymentEntity> payments;

  @override
  Widget build(BuildContext context) {
    final total = payments.fold(0.0, (sum, p) => sum + p.amount);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${payments.length} ta to\'lov',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            'Jami: \$${total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
          ),
        ],
      ),
    );
  }
}
