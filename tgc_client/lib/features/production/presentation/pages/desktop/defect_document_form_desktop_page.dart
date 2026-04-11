import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../data/datasources/defect_document_remote_datasource.dart';
import '../../../domain/entities/production_batch_entity.dart';
import '../../../domain/entities/production_batch_item_entity.dart';

class DefectDocumentFormDesktopPage extends StatefulWidget {
  final ProductionBatchEntity batch;

  const DefectDocumentFormDesktopPage({super.key, required this.batch});

  @override
  State<DefectDocumentFormDesktopPage> createState() =>
      _DefectDocumentFormDesktopPageState();
}

class _DefectDocumentFormDesktopPageState
    extends State<DefectDocumentFormDesktopPage> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();

  late final Map<int, TextEditingController> _qtyControllers;
  final List<XFile> _selectedPhotos = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _qtyControllers = {
      for (final item in widget.batch.items)
        item.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    _descController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<ProductionBatchItemEntity> get _items => widget.batch.items;

  Future<void> _pickPhotos() async {
    final source = await _showSourceSheet();
    if (source == null) return;

    final picker = ImagePicker();
    if (source == ImageSource.camera) {
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) setState(() => _selectedPhotos.add(photo));
    } else {
      final picked = await picker.pickMultiImage(imageQuality: 85);
      if (picked.isNotEmpty) setState(() => _selectedPhotos.addAll(picked));
    }
  }

  Future<ImageSource?> _showSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedCamera01,
                size: 22,
                strokeWidth: 2,
              ),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                size: 22,
                strokeWidth: 2,
              ),
              title: const Text('Galereya'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _removePhoto(int index) =>
      setState(() => _selectedPhotos.removeAt(index));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final itemsPayload = <Map<String, dynamic>>[];
    for (final item in _items) {
      final raw = _qtyControllers[item.id]?.text.trim() ?? '';
      final qty = int.tryParse(raw) ?? 0;
      if (qty > 0) {
        itemsPayload.add({
          'production_batch_item_id': item.id,
          'quantity': qty,
        });
      }
    }

    if (itemsPayload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamida bitta mahsulotda miqdor kiriting.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final photos = <MultipartFile>[];
      for (final xFile in _selectedPhotos) {
        photos.add(await MultipartFile.fromFile(
          xFile.path,
          filename: xFile.name,
        ));
      }

      await sl<DefectDocumentRemoteDataSource>().createDefectDocument(
        batchId:     widget.batch.id,
        description: _descController.text.trim(),
        items:       itemsPayload,
        photos:      photos.isEmpty ? null : photos,
      );

      if (context.mounted) context.pop(true);
    } catch (e) {
      if (context.mounted) {
        setState(() => _isSubmitting = false);
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
        title: Text('Nuxson rasmiylashtirish — #${widget.batch.id} ${widget.batch.batchTitle}'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const HugeIcon(
                    icon: HugeIcons.strokeRoundedFloppyDisk,
                    size: 18,
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
            label: const Text('Saqlash'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left: items table ──────────────────────────────────────────
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _ItemsTable(
                  items: _items,
                  controllers: _qtyControllers,
                ),
              ),
            ),
            // ── Right: description + photos ────────────────────────────────
            SizedBox(
              width: 360,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Izoh (majburiy)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _descController,
                              maxLines: 6,
                              decoration: const InputDecoration(
                                hintText:
                                    'Nuxsonning sababi va batafsil tavsifi...',
                                alignLabelWithHint: true,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().length < 5) {
                                  return 'Kamida 5 ta belgi kiriting';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rasmlar (ixtiyoriy)',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            if (_selectedPhotos.isNotEmpty) ...[
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _selectedPhotos
                                    .asMap()
                                    .entries
                                    .map(
                                      (e) => _DesktopPhotoThumb(
                                        xFile: e.value,
                                        onRemove: () => _removePhoto(e.key),
                                      ),
                                    )
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedCamera01,
                                  size: 18,
                                  strokeWidth: 2,
                                ),
                                label: Text(
                                  _selectedPhotos.isEmpty
                                      ? 'Rasm qo\'shish'
                                      : 'Yana rasm qo\'shish',
                                ),
                                onPressed: _pickPhotos,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Items table ───────────────────────────────────────────────────────────────

class _ItemsTable extends StatelessWidget {
  final List<ProductionBatchItemEntity> items;
  final Map<int, TextEditingController> controllers;

  const _ItemsTable({required this.items, required this.controllers});

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
              'Mahsulotlar — nuxson miqdorini kiriting',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Header row
          Container(
            color: AppColors.primary.withValues(alpha: 0.04),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text('#', style: labelStyle)),
                Expanded(
                    flex: 3, child: Text('Mahsulot', style: labelStyle)),
                Expanded(flex: 2, child: Text('Rang', style: labelStyle)),
                Expanded(
                    flex: 2, child: Text('O\'lcham', style: labelStyle)),
                SizedBox(
                  width: 80,
                  child: Text('Reja',
                      style: labelStyle, textAlign: TextAlign.center),
                ),
                SizedBox(
                  width: 100,
                  child: Text('Nuxson',
                      style: labelStyle, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Mahsulotlar yo\'q',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...items.asMap().entries.expand((entry) sync* {
              yield _DesktopItemRow(
                index:      entry.key,
                item:       entry.value,
                controller: controllers[entry.value.id]!,
              );
              if (entry.key < items.length - 1) {
                yield const Divider(height: 1, color: AppColors.divider);
              }
            }),
        ],
      ),
    );
  }
}

class _DesktopItemRow extends StatelessWidget {
  final int index;
  final ProductionBatchItemEntity item;
  final TextEditingController controller;

  const _DesktopItemRow({
    required this.index,
    required this.item,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: index.isOdd ? AppColors.surface.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
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
          Expanded(
            flex: 3,
            child: Text(
              item.productName,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
          Expanded(
            flex: 2,
            child: Text(
              item.sizeLength != null && item.sizeWidth != null
                  ? '${item.sizeLength}×${item.sizeWidth}'
                  : '—',
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
            width: 100,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '0',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final n = int.tryParse(v);
                  if (n == null || n < 0) return '≥0';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopPhotoThumb extends StatelessWidget {
  final XFile xFile;
  final VoidCallback onRemove;

  const _DesktopPhotoThumb({required this.xFile, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            xFile.path,
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 90,
              height: 90,
              color: AppColors.surface,
              child: const Icon(Icons.image_outlined),
            ),
          ),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
