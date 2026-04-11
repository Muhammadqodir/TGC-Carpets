import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../data/datasources/production_batch_remote_datasource.dart';
import '../../../domain/entities/production_batch_entity.dart';
import '../../../domain/entities/production_batch_item_entity.dart';
import '../../widgets/employee_picker_bottom_sheet.dart';

class ProductionBatchDetailMobilePage extends StatefulWidget {
  final ProductionBatchEntity batch;

  const ProductionBatchDetailMobilePage({super.key, required this.batch});

  @override
  State<ProductionBatchDetailMobilePage> createState() =>
      _ProductionBatchDetailMobilePageState();
}

class _ProductionBatchDetailMobilePageState
    extends State<ProductionBatchDetailMobilePage> {
  late Future<ProductionBatchEntity> _batchFuture;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _batchFuture = sl<ProductionBatchRemoteDataSource>()
        .getProductionBatch(widget.batch.id);
  }

  Future<void> _onStart(ProductionBatchEntity batch) async {
    final employee = await EmployeePickerBottomSheet.show(context);
    if (!context.mounted) return;

    if (employee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mas\'ul hodimni tanlash majburiy.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ishlab chiqarishni boshlash'),
        content: Text(
          'Mas\'ul hodim: ${employee.name}\n\nPartiyani ishlab chiqarishga o\'tkazasizmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Boshlash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _isActing = true);
    try {
      await sl<ProductionBatchRemoteDataSource>().startBatch(
        batch.id,
        responsibleEmployeeId: employee.id,
      );
      if (context.mounted) {
        setState(() {
          _batchFuture = sl<ProductionBatchRemoteDataSource>()
              .getProductionBatch(widget.batch.id);
          _isActing = false;
        });
        context.pop(true);
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _onCancel(ProductionBatchEntity batch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batchni bekor qilish'),
        content: const Text(
          'Haqiqatan ham bu batchni bekor qilmoqchimisiz? Bu amalni qaytarib bo\'lmaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Yo\'q'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ha, bekor qilish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    setState(() => _isActing = true);
    try {
      await sl<ProductionBatchRemoteDataSource>().cancelBatch(batch.id);
      if (context.mounted) {
        setState(() {
          _batchFuture = sl<ProductionBatchRemoteDataSource>()
              .getProductionBatch(widget.batch.id);
          _isActing = false;
        });
        context.pop(true);
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isActing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('#${widget.batch.id} — ${widget.batch.batchTitle}'),
        titleSpacing: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            strokeWidth: 2,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (widget.batch.status == 'planned')
            IconButton(
              tooltip: 'Tahrirlash',
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                strokeWidth: 2,
              ),
              onPressed: () async {
                final updated = await context.pushNamed(
                  AppRoutes.editProductionBatchName,
                  extra: widget.batch,
                );
                if (updated == true && context.mounted) {
                  context.pop(true);
                }
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: FutureBuilder<ProductionBatchEntity>(
        future: _batchFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ma\'lumotlarni yuklashda xatolik',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.error),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() {
                        _batchFuture = sl<ProductionBatchRemoteDataSource>()
                            .getProductionBatch(widget.batch.id);
                      }),
                      child: const Text('Qayta urinish'),
                    ),
                  ],
                ),
              ),
            );
          }
          final batch = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _batchFuture = sl<ProductionBatchRemoteDataSource>()
                    .getProductionBatch(widget.batch.id);
              });
              await _batchFuture;
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BatchInfoCard(batch: batch),
                  if (batch.status == 'planned' ||
                      (batch.status != 'completed' &&
                          batch.status != 'cancelled')) ...[
                    const SizedBox(height: 12),
                    if (batch.status == 'planned')
                      FilledButton.icon(
                        icon: _isActing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const HugeIcon(
                                icon: HugeIcons.strokeRoundedPlay,
                                size: 18,
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                        label:
                            const Text('Ishlab chiqarishni boshlash'),
                        onPressed:
                            _isActing ? null : () => _onStart(batch),
                      ),
                    if (batch.status == 'in_progress') ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side:
                              const BorderSide(color: AppColors.error),
                        ),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedAlert01,
                          size: 18,
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                        label: const Text('Nuxson rasmiylashtirish'),
                        onPressed: () async {
                          await context.pushNamed(
                            AppRoutes.defectDocumentFormName,
                            extra: batch,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (batch.status != 'completed' &&
                        batch.status != 'cancelled') ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side:
                              const BorderSide(color: AppColors.error),
                        ),
                        icon: _isActing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const HugeIcon(
                                icon:
                                    HugeIcons.strokeRoundedCancel01,
                                size: 18,
                                strokeWidth: 2,
                                color: AppColors.error,
                              ),
                        label: const Text('Bekor qilish'),
                        onPressed:
                            _isActing ? null : () => _onCancel(batch),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  _BatchItemsCard(items: batch.items),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _BatchInfoCard extends StatelessWidget {
  final ProductionBatchEntity batch;
  const _BatchInfoCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (batch.status) {
      'planned' => ('Rejalashtirilgan', AppColors.warning),
      'in_progress' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'completed' => ('Bajarildi', AppColors.success),
      'cancelled' => ('Bekor qilindi', AppColors.error),
      _ => (batch.status, AppColors.textSecondary),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Partiya ma\'lumotlari',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                _StatusBadge(label: statusLabel, color: statusColor),
              ],
            ),
            const Divider(height: 20),
            _InfoRow(
              icon: HugeIcons.strokeRoundedTag01,
              label: 'ID',
              value: '#${batch.id}',
            ),
            _InfoRow(
              icon: HugeIcons.strokeRoundedFactory,
              label: 'Tur',
              value: batch.typeLabel,
            ),
            if (batch.machine != null)
              _InfoRow(
                icon: HugeIcons.strokeRoundedSettings01,
                label: 'Stanok',
                value: batch.machine!.name,
              ),
            if (batch.creator != null)
              _InfoRow(
                icon: HugeIcons.strokeRoundedUser,
                label: 'Yaratdi',
                value: batch.creator!.name,
              ),
            if (batch.responsibleEmployee != null)
              _InfoRow(
                icon: HugeIcons.strokeRoundedUserCheck01,
                label: 'Mas\'ul',
                value: batch.responsibleEmployee!.name,
              ),
            if (batch.plannedDatetime != null)
              _InfoRow(
                icon: HugeIcons.strokeRoundedCalendar01,
                label: 'Reja sanasi',
                value: _fmtDt(batch.plannedDatetime!),
              ),
            if (batch.startedDatetime != null)
              _InfoRow(
                icon: HugeIcons.strokeRoundedPlay,
                label: 'Boshlandi',
                value: _fmtDt(batch.startedDatetime!),
              ),
            if (batch.completedDatetime != null)
              _InfoRow(
                icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                label: 'Yakunlandi',
                value: _fmtDt(batch.completedDatetime!),
              ),
            if (batch.notes != null && batch.notes!.isNotEmpty)
              _InfoRow(
                icon: HugeIcons.strokeRoundedNote01,
                label: 'Izoh',
                value: batch.notes!,
              ),
            const SizedBox(height: 4),
            const Divider(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Mahsulotlar',
                    value: '${batch.itemsCount} ta',
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Reja',
                    value:
                        '${batch.items.fold(0, (s, i) => s + i.plannedQuantity)} dona',
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Jami m²',
                    value:
                        '${batch.items.fold(0.0, (s, i) => s + i.plannedSqm).toStringAsFixed(2)} m²',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Items card ────────────────────────────────────────────────────────────────

class _BatchItemsCard extends StatelessWidget {
  final List<ProductionBatchItemEntity> items;
  const _BatchItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mahsulotlar ro\'yxati',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Mahsulotlar yo\'q',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              )
            else
              ...items.asMap().entries.map(
                    (entry) => _BatchItemTile(
                      item: entry.value,
                      index: entry.key + 1,
                      isLast: entry.key == items.length - 1,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _BatchItemTile extends StatelessWidget {
  final ProductionBatchItemEntity item;
  final int index;
  final bool isLast;

  const _BatchItemTile({
    required this.item,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final perUnitSqm = item.sizeLength != null && item.sizeWidth != null
        ? item.sizeLength! * item.sizeWidth! / 10000.0
        : 0.0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppThumbnail(imageUrl: item.colorImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      item.productName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    // Color / size
                    if (item.colorName != null || item.sizeLength != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _variantLabel(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    // Quality / type chips
                    if (item.qualityName != null ||
                        item.productTypeName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 4,
                          children: [
                            if (item.qualityName != null)
                              _MiniChip(
                                  label: item.qualityName!,
                                  color: AppColors.primary),
                            if (item.productTypeName != null)
                              _MiniChip(
                                  label: item.productTypeName!,
                                  color: AppColors.accent),
                          ],
                        ),
                      ),
                    // Source order
                    if (item.sourceOrderId != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedStore03,
                              size: 12,
                              strokeWidth: 3,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '#${item.sourceOrderId}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            if (item.sourceClientShopName != null) ...[
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.sourceClientShopName!,
                                  style: Theme.of(context).textTheme.labelSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right: production quantities
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // planned
                  _QtyBadge(
                    label: 'Reja',
                    value: '${item.plannedQuantity}',
                    color: AppColors.primary,
                  ),
                  // produced
                  if (item.producedQuantity != null) ...[
                    const SizedBox(height: 4),
                    _QtyBadge(
                      label: 'Tayyor',
                      value: '${item.producedQuantity}',
                      color: AppColors.success,
                    ),
                  ],
                  // defect
                  if (item.defectQuantity != null &&
                      item.defectQuantity! > 0) ...[
                    const SizedBox(height: 4),
                    _QtyBadge(
                      label: 'Nuxson',
                      value: '${item.defectQuantity}',
                      color: AppColors.error,
                    ),
                  ],
                  // sqm
                  if (perUnitSqm > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${item.plannedSqm.toStringAsFixed(2)} m²',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }

  String _variantLabel() {
    final parts = <String>[];
    if (item.colorName != null) parts.add(item.colorName!.toUpperCase());
    if (item.sizeLength != null && item.sizeWidth != null) {
      parts.add('${item.sizeLength}×${item.sizeWidth}');
    }
    return parts.join(' / ');
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: icon,
            size: 16,
            color: AppColors.textSecondary,
            strokeWidth: 2,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _QtyBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _QtyBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
      ],
    );
  }
}
