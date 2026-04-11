import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../data/datasources/defect_document_remote_datasource.dart';
import '../../../data/datasources/production_batch_remote_datasource.dart';
import '../../../domain/entities/defect_document_entity.dart';
import '../../../domain/entities/production_batch_entity.dart';
import '../../../domain/entities/production_batch_item_entity.dart';
import '../../widgets/employee_picker_bottom_sheet.dart';

/// Fetches the full batch (with items) from the API on load.
class ProductionBatchDetailDesktopPage extends StatefulWidget {
  /// Partial entity from the list (no items). Used to show title / ID
  /// before the full data arrives.
  final ProductionBatchEntity batch;

  const ProductionBatchDetailDesktopPage({super.key, required this.batch});

  @override
  State<ProductionBatchDetailDesktopPage> createState() =>
      _ProductionBatchDetailDesktopPageState();
}

class _ProductionBatchDetailDesktopPageState
    extends State<ProductionBatchDetailDesktopPage> {
  late Future<ProductionBatchEntity> _batchFuture;
  late Future<List<DefectDocumentEntity>> _defectDocsFuture;
  bool _isActing = false;

  @override
  void initState() {
    super.initState();
    _batchFuture = sl<ProductionBatchRemoteDataSource>()
        .getProductionBatch(widget.batch.id);
    _defectDocsFuture = _loadDefectDocs();
  }

  Future<List<DefectDocumentEntity>> _loadDefectDocs() async {
    final resp = await sl<DefectDocumentRemoteDataSource>()
        .getDefectDocuments(widget.batch.id);
    return resp.data;
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
          'Mas\'ul hodim: ${employee.name}\n\nBatchni ishlab chiqarishga o\'tkazasizmi?',
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('#${widget.batch.id} — ${widget.batch.batchTitle}'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          if (widget.batch.status == 'planned')
            IconButton(
              tooltip: 'Tahrirlash',
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                color: Colors.white,
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
          IconButton(
            onPressed: () {},
            tooltip: 'PDF',
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedPdf01,
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ma\'lumotlarni yuklashda xatolik',
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
            );
          }
          final batch = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _InfoSection(batch: batch),
                if (batch.status == 'planned' ||
                    (batch.status != 'completed' &&
                        batch.status != 'cancelled')) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (batch.status != 'completed' &&
                          batch.status != 'cancelled')
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          icon: _isActing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const HugeIcon(
                                  icon: HugeIcons.strokeRoundedCancel01,
                                  size: 18,
                                  strokeWidth: 2,
                                  color: AppColors.error,
                                ),
                          label: const Text('Bekor qilish'),
                          onPressed: _isActing ? null : () => _onCancel(batch),
                        ),
                      if (batch.status == 'in_progress') ...[
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
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
                            if (context.mounted) {
                              setState(() {
                                _defectDocsFuture = _loadDefectDocs();
                                _batchFuture =
                                    sl<ProductionBatchRemoteDataSource>()
                                        .getProductionBatch(widget.batch.id);
                              });
                            }
                          },
                        ),
                      ],
                      if (batch.status == 'planned') ...[
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          icon: _isActing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const HugeIcon(
                                  icon: HugeIcons.strokeRoundedPlay,
                                  size: 18,
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                          label: const Text('Ishlab chiqarishni boshlash'),
                          onPressed: _isActing ? null : () => _onStart(batch),
                        ),
                      ],
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _ItemsTable(items: batch.items),
                const SizedBox(height: 20),
                _DefectDocumentsSection(future: _defectDocsFuture),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Info section ──────────────────────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  final ProductionBatchEntity batch;
  const _InfoSection({required this.batch});

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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Partiya ma\'lumotlari',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                _InfoItem(label: 'ID', value: '#${batch.id}'),
                _InfoItem(label: 'Tur', value: batch.typeLabel),
                if (batch.machine != null)
                  _InfoItem(label: 'Stanok', value: batch.machine!.name),
                if (batch.creator != null)
                  _InfoItem(label: 'Yaratdi', value: batch.creator!.name),
                if (batch.responsibleEmployee != null)
                  _InfoItem(
                    label: 'Mas\'ul hodim',
                    value: batch.responsibleEmployee!.name,
                  ),
                if (batch.plannedDatetime != null)
                  _InfoItem(
                    label: 'Reja sanasi',
                    value: _fmtDt(batch.plannedDatetime!),
                  ),
                if (batch.startedDatetime != null)
                  _InfoItem(
                    label: 'Boshlandi',
                    value: _fmtDt(batch.startedDatetime!),
                  ),
                if (batch.completedDatetime != null)
                  _InfoItem(
                    label: 'Yakunlandi',
                    value: _fmtDt(batch.completedDatetime!),
                  ),
              ],
            ),
            if (batch.notes != null && batch.notes!.isNotEmpty) ...[
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
                      batch.notes!,
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

  String _fmtDt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Items table ───────────────────────────────────────────────────────────────

class _ItemsTable extends StatelessWidget {
  final List<ProductionBatchItemEntity> items;
  const _ItemsTable({required this.items});

  @override
  Widget build(BuildContext context) {
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Header
          Container(
            color: AppColors.primary.withValues(alpha: 0.04),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text('#', style: labelStyle)),
                Expanded(flex: 3, child: Text('Mahsulot', style: labelStyle)),
                Expanded(flex: 2, child: Text('Sifat', style: labelStyle)),
                Expanded(flex: 2, child: Text('Tur', style: labelStyle)),
                Expanded(flex: 2, child: Text('Rang', style: labelStyle)),
                Expanded(flex: 2, child: Text('O\'lcham', style: labelStyle)),
                Expanded(flex: 2, child: Text('Mijoz', style: labelStyle)),
                SizedBox(
                    width: 72,
                    child: Text('Reja',
                        style: labelStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 72,
                    child: Text('Tayor',
                        style: labelStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 72,
                    child: Text('Nuxson',
                        style: labelStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 90,
                    child: Text('Jami m²',
                        style: labelStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Rows
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Mahsulotlar yo\'q',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...items.asMap().entries.expand((entry) sync* {
              yield _buildRow(context, entry.key, entry.value);
              if (entry.key < items.length - 1) {
                yield const Divider(height: 1, color: AppColors.divider);
              }
            }),
          const Divider(height: 1, color: AppColors.divider),
          // Footer
          if (items.isNotEmpty) _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildRow(
      BuildContext context, int index, ProductionBatchItemEntity item) {
    final perUnitSqm = item.sizeLength != null && item.sizeWidth != null
        ? item.sizeLength! * item.sizeWidth! / 10000.0
        : 0.0;

    return Container(
      color: index.isOdd ? AppColors.surface.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Index
          SizedBox(
            width: 36,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          // Product name
          Expanded(
            flex: 3,
            child: Text(
              item.productName,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Quality
          Expanded(
            flex: 2,
            child: Text(
              item.qualityName ?? '—',
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Type
          Expanded(
            flex: 2,
            child: Text(
              item.productTypeName ?? '—',
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Color
          Expanded(
            flex: 2,
            child: Row(
              children: [
                AppThumbnail(imageUrl: item.colorImageUrl, size: 28),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.colorName?.toUpperCase() ?? '—',
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Size
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.sizeLength != null && item.sizeWidth != null
                      ? '${item.sizeLength}×${item.sizeWidth}'
                      : '—',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (perUnitSqm > 0)
                  Text(
                    '${perUnitSqm.toStringAsFixed(2)} m²',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
              ],
            ),
          ),
          // Source
          Expanded(
            flex: 2,
            child: item.sourceOrderId != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.sourceClientShopName != null)
                        Text(
                          item.sourceClientShopName!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  )
                : Text(
                    'Omborga',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
          ),
          // Planned qty
          SizedBox(
            width: 72,
            child: Text(
              '${item.plannedQuantity}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          // Produced qty
          SizedBox(
            width: 72,
            child: Text(
              item.producedQuantity != null ? '${item.producedQuantity}' : '—',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: item.producedQuantity != null
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
            ),
          ),
          // Defect qty
          SizedBox(
            width: 72,
            child: Text(
              item.defectQuantity != null && item.defectQuantity! > 0
                  ? '${item.defectQuantity}'
                  : '—',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        item.defectQuantity != null && item.defectQuantity! > 0
                            ? AppColors.error
                            : AppColors.textSecondary,
                  ),
            ),
          ),
          // Total sqm (planned)
          SizedBox(
            width: 90,
            child: Text(
              item.plannedSqm > 0
                  ? '${item.plannedSqm.toStringAsFixed(2)} m²'
                  : '—',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final totalPlanned = items.fold(0, (s, i) => s + i.plannedQuantity);
    final totalProduced = items.fold<int?>(
      null,
      (s, i) => i.producedQuantity != null ? (s ?? 0) + i.producedQuantity! : s,
    );
    final totalDefect = items.fold<int?>(
      null,
      (s, i) => i.defectQuantity != null ? (s ?? 0) + i.defectQuantity! : s,
    );
    final totalSqm = items.fold(0.0, (s, i) => s + i.plannedSqm);

    final footerStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        );

    return Container(
      color: AppColors.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const SizedBox(width: 36),
          Expanded(flex: 3, child: Text('Jami', style: footerStyle)),
          const Expanded(flex: 2, child: SizedBox.shrink()),
          const Expanded(flex: 2, child: SizedBox.shrink()),
          const Expanded(flex: 2, child: SizedBox.shrink()),
          const Expanded(flex: 2, child: SizedBox.shrink()),
          const Expanded(flex: 2, child: SizedBox.shrink()),
          SizedBox(
            width: 72,
            child: Text('$totalPlanned',
                textAlign: TextAlign.center, style: footerStyle),
          ),
          SizedBox(
            width: 72,
            child: Text(
              totalProduced != null ? '$totalProduced' : '—',
              textAlign: TextAlign.center,
              style: footerStyle?.copyWith(
                  color: totalProduced != null
                      ? AppColors.success
                      : AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              totalDefect != null && totalDefect > 0 ? '$totalDefect' : '—',
              textAlign: TextAlign.center,
              style: footerStyle?.copyWith(
                  color: totalDefect != null && totalDefect > 0
                      ? AppColors.error
                      : AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 90,
            child: Text(
              totalSqm > 0 ? '${totalSqm.toStringAsFixed(2)} m²' : '—',
              textAlign: TextAlign.center,
              style: footerStyle,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Defect documents section ──────────────────────────────────────────────────

class _DefectDocumentsSection extends StatelessWidget {
  final Future<List<DefectDocumentEntity>> future;
  const _DefectDocumentsSection({required this.future});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert01,
                  size: 18,
                  strokeWidth: 2,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  'Nuxson hujjatlari',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),
            FutureBuilder<List<DefectDocumentEntity>>(
              future: future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snap.hasError) {
                  return Text(
                    'Yuklashda xatolik',
                    style: TextStyle(color: AppColors.error),
                  );
                }
                final docs = snap.data!;
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Nuxson hujjatlari mavjud emas',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < docs.length; i++) ...[
                      _DefectDocRow(doc: docs[i]),
                      if (i < docs.length - 1)
                        const Divider(height: 24, color: AppColors.divider),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DefectDocRow extends StatelessWidget {
  final DefectDocumentEntity doc;
  const _DefectDocRow({required this.doc});

  @override
  Widget build(BuildContext context) {
    final dt = doc.datetime;
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    dateStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (doc.userName != null)
                    Text(
                      doc.userName!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.error.withAlpha(80)),
              ),
              child: Text(
                'Jami: ${doc.totalDefectQuantity} dona',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        if (doc.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(doc.description, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (doc.items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: doc.items
                .map(
                  (item) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Text(
                      '${_itemLabel(item)}: ${item.quantity} dona',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (doc.photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: doc.photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: AppThumbnail(
                    imageUrl: doc.photos[i].url,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _itemLabel(DefectDocumentItemEntity item) {
    if (item.batchItem == null) return '#${item.productionBatchItemId}';
    final b = item.batchItem!;
    final parts = <String>[];
    if (b.productName != null) parts.add(b.productName!);
    if (b.colorName != null) parts.add(b.colorName!);
    if (b.sizeLength != null && b.sizeWidth != null) {
      parts.add('${b.sizeLength}×${b.sizeWidth}');
    }
    return parts.isEmpty ? '#${item.productionBatchItemId}' : parts.join(' / ');
  }
}
