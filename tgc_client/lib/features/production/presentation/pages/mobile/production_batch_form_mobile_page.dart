import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/available_order_item_entity.dart';
import '../../../domain/entities/machine_entity.dart';
import '../../../domain/entities/production_batch_entity.dart';
import '../../../domain/repositories/production_repository.dart';
import '../../bloc/production_batch_form_bloc.dart';
import '../../bloc/production_batch_form_event.dart';
import '../../bloc/production_batch_form_state.dart';
import '../../widget/add_from_order_modal.dart';

class ProductionBatchFormMobilePage extends StatefulWidget {
  final ProductionBatchEntity? initialBatch;

  const ProductionBatchFormMobilePage({super.key, this.initialBatch});

  @override
  State<ProductionBatchFormMobilePage> createState() =>
      _ProductionBatchFormMobilePageState();
}

class _ProductionBatchFormMobilePageState
    extends State<ProductionBatchFormMobilePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  MachineEntity? _selectedMachine;
  DateTime? _plannedDatetime;
  String _selectedType = 'by_order';
  List<MachineEntity> _machines = [];
  final List<_MobileFormItem> _items = [];

  bool get _isEditMode => widget.initialBatch != null;

  @override
  void initState() {
    super.initState();
    _loadMachines();
    if (_isEditMode) {
      final b = widget.initialBatch!;
      _titleCtrl.text = b.batchTitle;
      _notesCtrl.text = b.notes ?? '';
      _plannedDatetime = b.plannedDatetime;
      _selectedType = b.type;
      for (final item in b.items) {
        _items.add(_MobileFormItem(
          sourceType: item.sourceType,
          sourceOrderItemId: item.sourceOrderItemId,
          productVariantId: item.variantId,
          plannedQuantity: item.plannedQuantity,
          label: item.variantLabel,
        ));
      }
    }
  }

  Future<void> _loadMachines() async {
    final repo = sl<ProductionRepository>();
    final result = await repo.getMachines();
    result.fold((_) {}, (paginated) {
      if (mounted) {
        setState(() {
          _machines = paginated.data;
          if (_isEditMode && widget.initialBatch!.machineId != null) {
            _selectedMachine = _machines
                .where((m) => m.id == widget.initialBatch!.machineId)
                .firstOrNull;
          }
        });
      }
    });
  }

  Future<void> _pickPlannedDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _plannedDatetime ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: _plannedDatetime != null
            ? TimeOfDay.fromDateTime(_plannedDatetime!)
            : TimeOfDay.now(),
      );
      if (time != null && mounted) {
        setState(() {
          _plannedDatetime = DateTime(
              date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _addFromOrder() async {
    final repo = sl<ProductionRepository>();
    final result = await repo.getAvailableOrderItems();

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (availableItems) async {
        final selected = await showDialog<List<Map<String, dynamic>>>(
          context: context,
          builder: (_) =>
              AddFromOrderModal(availableItems: availableItems),
        );

        if (selected != null && selected.isNotEmpty && mounted) {
          setState(() {
            for (final item in selected) {
              final display =
                  item['_display'] as AvailableOrderItemEntity;
              _items.add(_MobileFormItem(
                sourceType: 'order_item',
                sourceOrderItemId: item['source_order_item_id'] as int,
                productVariantId: item['product_variant_id'] as int,
                plannedQuantity: item['planned_quantity'] as int,
                label:
                    '${display.productName}${display.colorName != null ? ' - ${display.colorName}' : ''}',
              ));
            }
          });
        }
      },
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMachine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mashinani tanlang')),
      );
      return;
    }

    final items = _items
        .map((i) => {
              'source_type': i.sourceType,
              if (i.sourceOrderItemId != null)
                'source_order_item_id': i.sourceOrderItemId,
              'product_variant_id': i.productVariantId,
              'planned_quantity': i.plannedQuantity,
            })
        .toList();

    if (_isEditMode) {
      context.read<ProductionBatchFormBloc>().add(
            ProductionBatchFormUpdateSubmitted(
              batchId: widget.initialBatch!.id,
              batchTitle: _titleCtrl.text.trim(),
              machineId: _selectedMachine!.id,
              plannedDatetime: _plannedDatetime?.toIso8601String(),
              type: _selectedType,
              notes: _notesCtrl.text.trim(),
              items: items,
            ),
          );
    } else {
      context.read<ProductionBatchFormBloc>().add(
            ProductionBatchFormSubmitted(
              batchTitle: _titleCtrl.text.trim(),
              machineId: _selectedMachine!.id,
              plannedDatetime: _plannedDatetime?.toIso8601String(),
              type: _selectedType,
              notes: _notesCtrl.text.trim(),
              items: items,
            ),
          );
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductionBatchFormBloc, ProductionBatchFormState>(
      listener: (context, state) {
        if (state is ProductionBatchFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    _isEditMode ? 'Yangilandi' : 'Yaratildi')),
          );
          context.pop(true);
        } else if (state is ProductionBatchFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_isEditMode ? 'Tahrirlash' : 'Yangi partiya'),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
          actions: [
            BlocBuilder<ProductionBatchFormBloc, ProductionBatchFormState>(
              builder: (context, state) {
                final isSubmitting =
                    state is ProductionBatchFormSubmitting;
                return TextButton(
                  onPressed: isSubmitting ? null : _submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditMode ? 'Yangilash' : 'Saqlash'),
                );
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Partiya nomi *',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Majburiy' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: _selectedMachine?.id,
                decoration: const InputDecoration(
                  labelText: 'Mashina *',
                ),
                items: _machines
                    .map((m) => DropdownMenuItem(
                          value: m.id,
                          child: Text(m.name),
                        ))
                    .toList(),
                onChanged: (id) {
                  setState(() {
                    _selectedMachine =
                        _machines.where((m) => m.id == id).firstOrNull;
                  });
                },
                validator: (v) => v == null ? 'Majburiy' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickPlannedDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Rejadagi sana',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(
                    _plannedDatetime != null
                        ? '${_plannedDatetime!.day.toString().padLeft(2, '0')}.${_plannedDatetime!.month.toString().padLeft(2, '0')}.${_plannedDatetime!.year}'
                        : 'Tanlanmagan',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Izoh',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Mahsulotlar (${_items.length})',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addFromOrder,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Qo\'shish'),
                  ),
                ],
              ),
              const Divider(height: 1),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: Text('Hali mahsulot qo\'shilmagan'),
                  ),
                )
              else
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.label),
                    subtitle: Text(
                      'Miqdor: ${item.plannedQuantity}  ·  ${item.sourceType == 'order_item' ? 'Buyurtmadan' : 'Qo\'lda'}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppColors.error, size: 20),
                      onPressed: () => _removeItem(index),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileFormItem {
  final String sourceType;
  final int? sourceOrderItemId;
  final int productVariantId;
  final int plannedQuantity;
  final String label;

  _MobileFormItem({
    required this.sourceType,
    this.sourceOrderItemId,
    required this.productVariantId,
    required this.plannedQuantity,
    required this.label,
  });
}
