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

class DefectDocumentFormMobilePage extends StatefulWidget {
  final ProductionBatchEntity batch;

  const DefectDocumentFormMobilePage({super.key, required this.batch});

  @override
  State<DefectDocumentFormMobilePage> createState() =>
      _DefectDocumentFormMobilePageState();
}

class _DefectDocumentFormMobilePageState
    extends State<DefectDocumentFormMobilePage> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();

  /// batchItemId → qty controller
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
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() => _selectedPhotos.addAll(picked));
    }
  }

  void _removePhoto(int index) =>
      setState(() => _selectedPhotos.removeAt(index));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Build items list — only those with a quantity > 0
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

      if (context.mounted) {
        context.pop(true);
      }
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
      appBar: AppBar(
        title: Text('Nuxson — #${widget.batch.id}'),
        titleSpacing: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            strokeWidth: 2,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Saqlash',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Description ─────────────────────────────────────────────
            _SectionHeader(title: 'Izoh (majburiy)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Nuxsonning sababi va batafsil tavsifi...',
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if (v == null || v.trim().length < 5) {
                  return 'Kamida 5 ta belgi kiriting';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Items ────────────────────────────────────────────────────
            _SectionHeader(title: 'Mahsulotlar (nuxson miqdorini kiriting)'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: _items.asMap().entries.map((entry) {
                  final idx  = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      _MobileItemRow(
                        item: item,
                        controller: _qtyControllers[item.id]!,
                      ),
                      if (idx < _items.length - 1)
                        const Divider(height: 1, color: AppColors.divider),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Photos ───────────────────────────────────────────────────
            _SectionHeader(title: 'Rasmlar (ixtiyoriy)'),
            const SizedBox(height: 8),
            if (_selectedPhotos.isNotEmpty) ...[
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedPhotos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => _PhotoThumb(
                    xFile: _selectedPhotos[index],
                    onRemove: () => _removePhoto(index),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Mobile item row ───────────────────────────────────────────────────────────

class _MobileItemRow extends StatelessWidget {
  final ProductionBatchItemEntity item;
  final TextEditingController controller;

  const _MobileItemRow({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          AppThumbnail(imageUrl: item.colorImageUrl, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.colorName != null || item.sizeLength != null)
                  Text(
                    [
                      if (item.colorName != null)
                        item.colorName!.toUpperCase(),
                      if (item.sizeLength != null && item.sizeWidth != null)
                        '${item.sizeLength}×${item.sizeWidth}',
                    ].join(' / '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                Text(
                  'Reja: ${item.plannedQuantity} dona',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
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

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final XFile xFile;
  final VoidCallback onRemove;

  const _PhotoThumb({required this.xFile, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            xFile.path,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 100,
              height: 100,
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
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
