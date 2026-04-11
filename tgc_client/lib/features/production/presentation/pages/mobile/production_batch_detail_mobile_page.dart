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

class ProductionBatchDetailMobilePage extends StatefulWidget {
  final ProductionBatchEntity initialBatch;

  const ProductionBatchDetailMobilePage({
    super.key,
    required this.initialBatch,
  });

  @override
  State<ProductionBatchDetailMobilePage> createState() =>
      _ProductionBatchDetailMobilePageState();
}

class _ProductionBatchDetailMobilePageState
    extends State<ProductionBatchDetailMobilePage> {
  late ProductionBatchEntity _batch;

  @override
  void initState() {
    super.initState();
    _batch = widget.initialBatch;
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductionBatchFormBloc, ProductionBatchFormState>(
      listener: (context, state) {
        if (state is ProductionBatchFormSuccess) {
          setState(() => _batch = state.batch);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Yangilandi')),
          );
        } else if (state is ProductionBatchLoaded) {
          setState(() => _batch = state.batch);
        } else if (state is ProductionBatchFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is ProductionBatchItemUpdated) {
          context
              .read<ProductionBatchFormBloc>()
              .add(ProductionBatchLoadRequested(_batch.id));
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            _batch.batchTitle,
            overflow: TextOverflow.ellipsis,
          ),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => context.pop(true),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
          actions: [
            if (_batch.status == 'planned')
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
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
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusBar(context),
            const SizedBox(height: 12),
            _buildInfoCard(context),
            const SizedBox(height: 12),
            _buildActionButtons(context),
            const SizedBox(height: 16),
            Text(
              'Mahsulotlar (${_batch.effectiveItemsCount})',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._batch.items.map(
                (item) => _buildItemCard(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(BuildContext context) {
    final (statusLabel, statusColor) = switch (_batch.status) {
      'planned' => ('Rejalashtirilgan', AppColors.warning),
      'in_progress' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'completed' => ('Yakunlangan', AppColors.success),
      'cancelled' => ('Bekor qilingan', AppColors.error),
      _ => (_batch.status, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: statusColor),
          const SizedBox(width: 8),
          Text(
            statusLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
          const Spacer(),
          Text(
            '#${_batch.id}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(context, 'Mashina', _batch.machineName ?? '—'),
            if (_batch.creatorName != null)
              _infoRow(context, 'Yaratuvchi', _batch.creatorName!),
            _infoRow(context, 'Tur', _batch.typeLabel),
            if (_batch.plannedDatetime != null)
              _infoRow(context, 'Reja',
                  _formatDateTime(_batch.plannedDatetime!)),
            if (_batch.startedDatetime != null)
              _infoRow(context, 'Boshlangan',
                  _formatDateTime(_batch.startedDatetime!)),
            if (_batch.completedDatetime != null)
              _infoRow(context, 'Yakunlangan',
                  _formatDateTime(_batch.completedDatetime!)),
            _infoRow(context, 'Jami reja',
                '${_batch.totalPlannedQuantity} dona'),
            _infoRow(context, 'Ishlab chiqarilgan',
                '${_batch.totalProducedQuantity} dona'),
            _infoRow(
                context, 'Nuqsonli', '${_batch.totalDefectQuantity} dona'),
            if (_batch.notes != null && _batch.notes!.isNotEmpty) ...[
              const Divider(height: 16),
              Text(
                _batch.notes!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return BlocBuilder<ProductionBatchFormBloc, ProductionBatchFormState>(
      builder: (context, state) {
        final isLoading = state is ProductionBatchFormSubmitting;

        return Row(
          children: [
            if (_batch.status == 'planned')
              Expanded(
                child: FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => context
                          .read<ProductionBatchFormBloc>()
                          .add(ProductionBatchStartRequested(_batch.id)),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Boshlash'),
                ),
              ),
            if (_batch.status == 'in_progress')
              Expanded(
                child: FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => context
                          .read<ProductionBatchFormBloc>()
                          .add(ProductionBatchCompleteRequested(
                              _batch.id)),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Yakunlash'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success),
                ),
              ),
            if (_batch.status != 'completed' &&
                _batch.status != 'cancelled') ...[
              const SizedBox(width: 8),
              OutlinedButton(
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
                child: const Text('Bekor qilish',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildItemCard(
      BuildContext context, ProductionBatchItemEntity item) {
    final progress = item.progressPercent;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppThumbnail(imageUrl: item.colorImageUrl, size: 36),
                const SizedBox(width: 10),
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
                      if (item.colorName != null ||
                          (item.sizeLength != null &&
                              item.sizeWidth != null))
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
            const SizedBox(height: 8),
            Row(
              children: [
                _countBadge(context, 'Reja', '${item.plannedQuantity}',
                    AppColors.primary),
                const SizedBox(width: 6),
                _countBadge(context, 'Holati', '${item.producedQuantity}',
                    AppColors.success),
                const SizedBox(width: 6),
                _countBadge(context, 'Nuqson', '${item.defectQuantity}',
                    AppColors.error),
              ],
            ),
            const SizedBox(height: 6),
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
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(
      BuildContext context, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
      ),
    );
  }
}
