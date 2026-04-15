import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../clients/domain/entities/client_entity.dart';
import '../../../clients/presentation/widgets/client_picker_bottom_sheet.dart';
import '../../../orders/data/datasources/order_remote_datasource.dart';
import '../../../orders/domain/entities/order_entity.dart';
import '../bloc/payment_form_bloc.dart';
import '../bloc/payment_form_event.dart';
import '../bloc/payment_form_state.dart';

/// Full-screen dialog for logging a new payment.
class AddPaymentPage extends StatelessWidget {
  const AddPaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<PaymentFormBloc>(),
      child: const _AddPaymentView(),
    );
  }
}

class _AddPaymentView extends StatefulWidget {
  const _AddPaymentView();

  @override
  State<_AddPaymentView> createState() => _AddPaymentViewState();
}

class _AddPaymentViewState extends State<_AddPaymentView> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  ClientEntity? _selectedClient;
  OrderEntity? _selectedOrder;
  List<OrderEntity> _clientOrders = [];
  bool _loadingOrders = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickClient() async {
    final client = await ClientPickerBottomSheet.show(context);
    if (client != null && mounted) {
      setState(() {
        _selectedClient = client;
        _selectedOrder = null;
        _clientOrders = [];
      });
      await _loadOrders(client.id);
    }
  }

  Future<void> _loadOrders(int clientId) async {
    setState(() => _loadingOrders = true);
    try {
      final ds = sl<OrderRemoteDataSource>();
      final result = await ds.getOrders(
        clientId: clientId,
        perPage: 50,
      );
      if (mounted) {
        setState(() {
          _clientOrders = result.data;
          _loadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amountText = _amountCtrl.text.trim().replaceAll(',', '.');
    final amount = double.tryParse(amountText) ?? 0;

    context.read<PaymentFormBloc>().add(
          PaymentFormSubmitted(
            clientId: _selectedClient!.id,
            orderId: _selectedOrder?.id,
            amount: amount,
            notes: _notesCtrl.text.trim().isEmpty
                ? null
                : _notesCtrl.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentFormBloc, PaymentFormState>(
      listener: (context, state) {
        if (state is PaymentFormSuccess) {
          context.pop(true);
        } else if (state is PaymentFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text("To'lov qo'shish"),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Client ────────────────────────────────────────────────────
              _SectionLabel(label: 'Mijoz *'),
              const SizedBox(height: 6),
              _ClientPickerField(
                client: _selectedClient,
                onTap: _pickClient,
                onClear: () => setState(() {
                  _selectedClient = null;
                  _selectedOrder = null;
                  _clientOrders = [];
                }),
                validator: (_) => _selectedClient == null
                    ? 'Iltimos, mijozni tanlang'
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Order (optional) ───────────────────────────────────────────
              _SectionLabel(label: "Buyurtma (ixtiyoriy)"),
              const SizedBox(height: 6),
              if (_loadingOrders)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_selectedClient == null)
                _DisabledField(hint: 'Avval mijozni tanlang')
              else if (_clientOrders.isEmpty)
                _DisabledField(hint: 'Ushbu mijoz uchun buyurtma topilmadi')
              else
                _OrderDropdown(
                  orders: _clientOrders,
                  selectedOrder: _selectedOrder,
                  onChanged: (order) =>
                      setState(() => _selectedOrder = order),
                ),
              const SizedBox(height: 16),

              // ── Amount ─────────────────────────────────────────────────────
              _SectionLabel(label: "Miqdor (\$) *"),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixText: '\$ ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Miqdor kiritilsinl';
                  final parsed =
                      double.tryParse(v.trim().replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) {
                    return "Musbat raqam kiriting";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Notes ──────────────────────────────────────────────────────
              _SectionLabel(label: 'Izoh (ixtiyoriy)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: "Qo'shimcha izoh...",
                ),
              ),
              const SizedBox(height: 32),

              // ── Submit ─────────────────────────────────────────────────────
              BlocBuilder<PaymentFormBloc, PaymentFormState>(
                builder: (context, state) {
                  final isSubmitting = state is PaymentFormSubmitting;
                  return FilledButton.icon(
                    onPressed: isSubmitting ? null : _submit,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 20,
                          ),
                    label: Text(
                        isSubmitting ? 'Saqlanmoqda...' : "To'lovni saqlash"),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelMedium
          ?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
    );
  }
}

class _ClientPickerField extends FormField<String> {
  _ClientPickerField({
    required ClientEntity? client,
    required VoidCallback onTap,
    required VoidCallback onClear,
    super.validator,
  }) : super(
          builder: (field) {
            final isSelected = client != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.05)
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: field.hasError
                            ? AppColors.error
                            : isSelected
                                ? AppColors.primary
                                : AppColors.divider,
                        width: isSelected && !field.hasError ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.store_outlined,
                          size: 18,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            client?.shopName ?? 'Mijoz tanlang',
                            style: TextStyle(
                              color: isSelected
                                  ? null
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          GestureDetector(
                            onTap: onClear,
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      field.errorText!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12),
                    ),
                  ),
              ],
            );
          },
        );
}

class _DisabledField extends StatelessWidget {
  const _DisabledField({required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        hint,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _OrderDropdown extends StatelessWidget {
  const _OrderDropdown({
    required this.orders,
    required this.selectedOrder,
    required this.onChanged,
  });

  final List<OrderEntity> orders;
  final OrderEntity? selectedOrder;
  final ValueChanged<OrderEntity?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<OrderEntity>(
      value: selectedOrder,
      hint: const Text('Buyurtma tanlang (ixtiyoriy)'),
      isExpanded: true,
      items: [
        const DropdownMenuItem<OrderEntity>(
          value: null,
          child: Text('— Buyurtmasiz —'),
        ),
        ...orders.map(
          (o) => DropdownMenuItem<OrderEntity>(
            value: o,
            child: Text(
              '#${o.id}  ${o.clientShopName ?? ''}  (${o.statusLabel})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
