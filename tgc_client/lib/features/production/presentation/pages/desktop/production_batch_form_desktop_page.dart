import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../domain/entities/available_order_item_entity.dart';
import '../../../domain/entities/machine_entity.dart';
import '../../../domain/entities/production_batch_entity.dart';
import '../../../domain/repositories/production_repository.dart';
import '../../bloc/production_batch_form_bloc.dart';
import '../../bloc/production_batch_form_event.dart';
import '../../bloc/production_batch_form_state.dart';
import '../../widget/add_from_order_modal.dart';

class ProductionBatchFormDesktopPage extends StatefulWidget {
  final ProductionBatchEntity? initialBatch;

  const ProductionBatchFormDesktopPage({super.key, this.initialBatch});

  @override
  State<ProductionBatchFormDesktopPage> createState() =>
      _ProductionBatchFormDesktopPageState();
}

class _ProductionBatchFormDesktopPageState
    extends State<ProductionBatchFormDesktopPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  MachineEntity? _selectedMachine;
  DateTime? _plannedDatetime;
  String _selectedType = 'by_order';
  List<MachineEntity> _machines = [];

  // Items to include in batch
  final List<_BatchFormItem> _items = [];

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
      // Pre-fill items
      for (final item in b.items) {
        _items.add(_BatchFormItem(
          sourceType: item.sourceType,
          sourceOrderItemId: item.sourceOrderItemId,
          productVariantId: item.variantId,
          plannedQuantity: item.plannedQuantity,
          productName: item.productName,
          colorName: item.colorName,
          colorImageUrl: item.colorImageUrl,
          sizeLength: item.sizeLength,
          sizeWidth: item.sizeWidth,
          sourceLabel: item.sourceLabel,
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
              _items.add(_BatchFormItem(
                sourceType: 'order_item',
                sourceOrderItemId: item['source_order_item_id'] as int,
                productVariantId: item['product_variant_id'] as int,
                plannedQuantity: item['planned_quantity'] as int,
                productName: display.productName,
                colorName: display.colorName,
                colorImageUrl: display.colorImageUrl,
                sizeLength: display.sizeLength,
                sizeWidth: display.sizeWidth,
                sourceLabel:
                    '#${display.orderNumber}${display.clientShopName != null ? ' (${display.clientShopName})' : ''}',
              ));
            }
            _updateType();
          });
        }
      },
    );
  }

  void _addManualItem() {
    // For manual items, we'd need a variant picker — simplified here
    // In a real implementation, reuse the product picker from orders
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text(
              'Mahsulot tanlash uchun "Buyurtmadan qo\'shish" tugmasini ishlating')),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _updateType();
    });
  }

  void _updateType() {
    final hasOrder = _items.any((i) => i.sourceType == 'order_item');
    final hasManual =
        _items.any((i) => i.sourceType == 'manual' || i.sourceType == 'stock_request');
    if (hasOrder && hasManual) {
      _selectedType = 'mixed';
    } else if (hasOrder) {
      _selectedType = 'by_order';
    } else if (hasManual) {
      _selectedType = 'for_stock';
    }
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

    final plannedStr = _plannedDatetime?.toIso8601String();

    if (_isEditMode) {
      context.read<ProductionBatchFormBloc>().add(
            ProductionBatchFormUpdateSubmitted(
              batchId: widget.initialBatch!.id,
              batchTitle: _titleCtrl.text.trim(),
              machineId: _selectedMachine!.id,
              plannedDatetime: plannedStr,
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
              plannedDatetime: plannedStr,
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
                content: Text(_isEditMode
                    ? 'Partiya yangilandi'
                    : 'Partiya yaratildi')),
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
          title: Text(_isEditMode
              ? 'Partiyani tahrirlash'
              : 'Yangi partiya yaratish'),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // General Info section
                _buildGeneralInfoCard(context),
                const SizedBox(height: 20),
                // Items section
                _buildItemsCard(context),
                const SizedBox(height: 24),
                // Submit button
                BlocBuilder<ProductionBatchFormBloc,
                    ProductionBatchFormState>(
                  builder: (context, state) {
                    final isSubmitting =
                        state is ProductionBatchFormSubmitting;
                    return SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: isSubmitting ? null : _submit,
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(_isEditMode ? 'Yangilash' : 'Yaratish'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Umumiy ma\'lumotlar',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Partiya nomi *',
                      hintText: 'masalan: Partiya #1 - 11.04.2026',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Majburiy' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
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
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickPlannedDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Rejadagi sana',
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _plannedDatetime != null
                            ? '${_plannedDatetime!.day.toString().padLeft(2, '0')}.${_plannedDatetime!.month.toString().padLeft(2, '0')}.${_plannedDatetime!.year} ${_plannedDatetime!.hour.toString().padLeft(2, '0')}:${_plannedDatetime!.minute.toString().padLeft(2, '0')}'
                            : 'Tanlanmagan',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tur',
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'by_order',
                          child: Text('Buyurtma bo\'yicha')),
                      DropdownMenuItem(
                          value: 'for_stock',
                          child: Text('Zaxira uchun')),
                      DropdownMenuItem(
                          value: 'mixed', child: Text('Aralash')),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedType = v!);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Izoh',
                hintText: 'Qo\'shimcha ma\'lumotlar...',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        );

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'Mahsulotlar',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _addFromOrder,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                  label: const Text('Buyurtmadan qo\'shish'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _addManualItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Qo\'lda qo\'shish'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Header
          Container(
            color: AppColors.primary.withValues(alpha: 0.04),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                    width: 40, child: Text('#', style: labelStyle)),
                Expanded(
                    flex: 3,
                    child: Text('Mahsulot', style: labelStyle)),
                Expanded(
                    flex: 2,
                    child: Text('Manba', style: labelStyle)),
                SizedBox(
                    width: 100,
                    child: Text('Miqdor',
                        textAlign: TextAlign.center,
                        style: labelStyle)),
                SizedBox(
                    width: 50,
                    child: Text('',
                        textAlign: TextAlign.center,
                        style: labelStyle)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Mahsulotlar qo\'shilmagan. "Buyurtmadan qo\'shish" tugmasini bosing.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: index.isOdd
                        ? AppColors.surface.withValues(alpha: 0.5)
                        : null,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text('${index + 1}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.textSecondary)),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              AppThumbnail(
                                imageUrl: item.colorImageUrl,
                                size: 32,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      [
                                        if (item.colorName != null)
                                          item.colorName!,
                                        if (item.sizeLength != null &&
                                            item.sizeWidth != null)
                                          '${item.sizeLength}x${item.sizeWidth}',
                                      ].join(' / '),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color:
                                                  AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            item.sourceLabel,
                            style:
                                Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            '${item.plannedQuantity}',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: IconButton(
                            icon: const Icon(Icons.close,
                                size: 18, color: AppColors.error),
                            onPressed: () => _removeItem(index),
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < _items.length - 1)
                    const Divider(height: 1, color: AppColors.divider),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _BatchFormItem {
  final String sourceType;
  final int? sourceOrderItemId;
  final int productVariantId;
  int plannedQuantity;
  final String productName;
  final String? colorName;
  final String? colorImageUrl;
  final int? sizeLength;
  final int? sizeWidth;
  final String sourceLabel;

  _BatchFormItem({
    required this.sourceType,
    this.sourceOrderItemId,
    required this.productVariantId,
    required this.plannedQuantity,
    required this.productName,
    this.colorName,
    this.colorImageUrl,
    this.sizeLength,
    this.sizeWidth,
    required this.sourceLabel,
  });
}
