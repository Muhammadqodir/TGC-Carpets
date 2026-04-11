import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/dialogs/confirm_dialog.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../domain/entities/production_batch_entity.dart';
import '../../../domain/entities/production_batch_item_entity.dart';
import '../../bloc/production_batch_form_bloc.dart';
import '../../bloc/production_batch_form_event.dart';
import '../../bloc/production_batch_form_state.dart';

class ProductionBatchDetailDesktopPage extends StatefulWidget {
  final ProductionBatchEntity initialBatch;

  const ProductionBatchDetailDesktopPage({
    super.key,
    required this.initialBatch,
  });

  @override
  State<ProductionBatchDetailDesktopPage> createState() =>
      _ProductionBatchDetailDesktopPageState();
}

class _ProductionBatchDetailDesktopPageState
    extends State<ProductionBatchDetailDesktopPage> {
  late ProductionBatchEntity _batch;

  @override
  void initState() {
    super.initState();
    _batch = widget.initialBatch;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductionBatchFormBloc, ProductionBatchFormState>(
      listener: (context, state) {
        if (state is ProductionBatchFormSuccess) {
          setState(() => _batch = state.batch);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Muvaffaqiyatli yangilandi')),
          );
        } else if (state is ProductionBatchLoaded) {
          setState(() => _batch = state.batch);
        } else if (state is ProductionBatchFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is ProductionBatchItemUpdated) {
          // Reload entire batch
          context
              .read<ProductionBatchFormBloc>()
              .add(ProductionBatchLoadRequested(_batch.id));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_batch.batchTitle),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => context.pop(true),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
          actions: [
            if (_batch.status == 'planned')
              TextButton.icon(
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Tahrirlash'),
                onPressed: () async {
                  final updated = await context.pushNamed(
                    AppRoutes.editProductionBatchName,
                    extra: _batch,
                  );
                  if (updated == true && context.mounted) {
                    context
                        .read<ProductionBatchFormBloc>()
                        .add(ProductionBatchLoadRequested(_batch.id));
                  }
                },
              ),
            const SizedBox(width: 12),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInfoSection(context),
              const SizedBox(height: 16),
              _buildActionsSection(context),
              const SizedBox(height: 20),
              _buildItemsTable(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    final (statusLabel, statusColor) = switch (_batch.status) {
      'planned' => ('Rejalashtirilgan', AppColors.warning),
      'in_progress' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'completed' => ('Yakunlangan', AppColors.success),
      'cancelled' => ('Bekor qilingan', AppColors.error),
      _ => (_batch.status, AppColors.textSecondary),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Partiya ma\'lumotlari',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withAlpha(100)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 40,
              runSpacing: 12,
              children: [
                _InfoItem(label: 'ID', value: '#${_batch.id}'),
                _InfoItem(
                  label: 'Mashina',
                  value: _batch.machineName ?? '—',
                ),
                if (_batch.creatorName != null)
                  _InfoItem(label: 'Yaratuvchi', value: _batch.creatorName!),
                _InfoItem(label: 'Tur', value: _batch.typeLabel),
                if (_batch.plannedDatetime != null)
                  _InfoItem(
                    label: 'Rejadagi sana',
                    value: _formatDateTime(_batch.plannedDatetime!),
                  ),
                if (_batch.startedDatetime != null)
                  _InfoItem(
                    label: 'Boshlangan',
                    value: _formatDateTime(_batch.startedDatetime!),
                  ),
                if (_batch.completedDatetime != null)
                  _InfoItem(
                    label: 'Yakunlangan',
                    value: _formatDateTime(_batch.completedDatetime!),
                  ),
              ],
            ),
            if (_batch.notes != null && _batch.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Izoh: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Expanded(
                    child: Text(
                      _batch.notes!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return BlocBuilder<ProductionBatchFormBloc, ProductionBatchFormState>(
      builder: (context, state) {
        final isLoading = state is ProductionBatchFormSubmitting;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.precision_manufacturing_outlined,
                    size: 20),
                const SizedBox(width: 8),
                Text(
                  'Boshqarish',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (_batch.status == 'planned') ...[
                  FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : () {
                            context.read<ProductionBatchFormBloc>().add(
                                  ProductionBatchStartRequested(_batch.id),
                                );
                          },
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Ishlab chiqarishni boshlash'),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_batch.status == 'in_progress') ...[
                  FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : () {
                            context.read<ProductionBatchFormBloc>().add(
                                  ProductionBatchCompleteRequested(
                                      _batch.id),
                                );
                          },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Yakunlash'),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_batch.status != 'completed' &&
                    _batch.status != 'cancelled')
                  OutlinedButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final confirmed = await ConfirmDialog.show(
                              context: context,
                              title: 'Bekor qilish',
                              content:
                                  'Partiyani bekor qilishni xohlaysizmi?',
                            );
                            if (confirmed && context.mounted) {
                              context
                                  .read<ProductionBatchFormBloc>()
                                  .add(ProductionBatchCancelRequested(
                                      _batch.id));
                            }
                          },
                    icon: const Icon(Icons.cancel_outlined,
                        size: 18, color: AppColors.error),
                    label: const Text('Bekor qilish',
                        style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemsTable(BuildContext context) {
    final items = _batch.items;
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
            child: Text(
              'Mahsulotlar ro\'yxati',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
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
                    width: 80,
                    child: Text('Reja',
                        textAlign: TextAlign.center,
                        style: labelStyle)),
                SizedBox(
                    width: 80,
                    child: Text('Ishlab chiq.',
                        textAlign: TextAlign.center,
                        style: labelStyle)),
                SizedBox(
                    width: 80,
                    child: Text('Nuqson',
                        textAlign: TextAlign.center,
                        style: labelStyle)),
                SizedBox(
                    width: 120,
                    child: Text('Progress',
                        textAlign: TextAlign.center,
                        style: labelStyle)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Mahsulotlar topilmadi')),
            )
          else
            ...items.asMap().entries.expand((entry) sync* {
              yield _buildItemRow(context, entry.key, entry.value);
              if (entry.key < items.length - 1) {
                yield const Divider(height: 1, color: AppColors.divider);
              }
            }),
          const Divider(height: 1, color: AppColors.divider),
          // Totals
          Container(
            color: AppColors.primary.withValues(alpha: 0.06),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Jami',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                  ),
                ),
                const Expanded(flex: 2, child: SizedBox.shrink()),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${_batch.totalPlannedQuantity}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${_batch.totalProducedQuantity}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${_batch.totalDefectQuantity}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                  ),
                ),
                const SizedBox(width: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(
      BuildContext context, int index, ProductionBatchItemEntity item) {
    final progress = item.progressPercent;

    return Container(
      color: index.isOdd ? AppColors.surface.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                AppThumbnail(imageUrl: item.colorImageUrl, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [
                          if (item.colorName != null) item.colorName!,
                          if (item.sizeLength != null &&
                              item.sizeWidth != null)
                            '${item.sizeLength}x${item.sizeWidth}',
                        ].join(' / '),
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
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
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 80,
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
            width: 80,
            child: _batch.status == 'in_progress'
                ? _EditableQuantity(
                    value: item.producedQuantity,
                    onChanged: (val) {
                      context.read<ProductionBatchFormBloc>().add(
                            ProductionBatchItemUpdateRequested(
                              batchId: _batch.id,
                              itemId: item.id,
                              producedQuantity: val,
                            ),
                          );
                    },
                  )
                : Text(
                    '${item.producedQuantity}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
          ),
          SizedBox(
            width: 80,
            child: _batch.status == 'in_progress'
                ? _EditableQuantity(
                    value: item.defectQuantity,
                    onChanged: (val) {
                      context.read<ProductionBatchFormBloc>().add(
                            ProductionBatchItemUpdateRequested(
                              batchId: _batch.id,
                              itemId: item.id,
                              defectQuantity: val,
                            ),
                          );
                    },
                  )
                : Text(
                    '${item.defectQuantity}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                            color: item.defectQuantity > 0
                                ? AppColors.error
                                : null),
                  ),
          ),
          SizedBox(
            width: 120,
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.divider,
                    valueColor: AlwaysStoppedAnimation(
                      progress >= 1.0
                          ? AppColors.success
                          : AppColors.primaryLight,
                    ),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _EditableQuantity extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _EditableQuantity({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_EditableQuantity> createState() => _EditableQuantityState();
}

class _EditableQuantityState extends State<_EditableQuantity> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
  }

  @override
  void didUpdateWidget(covariant _EditableQuantity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        onSubmitted: (val) {
          final qty = int.tryParse(val) ?? 0;
          if (qty >= 0) widget.onChanged(qty);
        },
      ),
    );
  }
}
