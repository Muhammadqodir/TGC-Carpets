import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/product_quality_entity.dart';
import '../../domain/entities/product_type_entity.dart';
import '../bloc/import_products_bloc.dart';
import '../bloc/import_products_event.dart';
import '../bloc/import_products_state.dart';

class ImportProductsPage extends StatelessWidget {
  const ImportProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ImportProductsBloc>()..add(const ImportProductsStarted()),
      child: const _ImportProductsView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ImportProductsView extends StatelessWidget {
  const _ImportProductsView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ImportProductsBloc, ImportProductsState>(
      listener: (context, state) {
        if (state is ImportProductsSuccess) {
          final parts = <String>[];
          if (state.createdProducts > 0) {
            parts.add('${state.createdProducts} ta yangi mahsulot');
          }
          if (state.createdColors > 0) {
            parts.add('${state.createdColors} ta rang qo\'shildi');
          }
          if (state.skipped > 0) {
            parts.add('${state.skipped} ta o\'tkazib yuborildi');
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                parts.isEmpty ? 'Hech narsa o\'zgarmadi.' : parts.join(', '),
              ),
              backgroundColor: state.createdProducts + state.createdColors > 0
                  ? AppColors.success
                  : AppColors.warning,
            ),
          );
          context.pop(true);
        } else if (state is ImportProductsFailure) {
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
          title: const Text('Mahsulotlarni import qilish'),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
          actions: [
            BlocBuilder<ImportProductsBloc, ImportProductsState>(
              builder: (context, state) {
                if (state is ImportProductsSubmitting) {
                  return const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                final canSave =
                    state is ImportProductsReady && state.entries.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton(
                    onPressed: canSave
                        ? () => context
                            .read<ImportProductsBloc>()
                            .add(const ImportProductsSubmitted())
                        : null,
                    child: Text(
                      'Saqlash',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                          ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<ImportProductsBloc, ImportProductsState>(
          builder: (context, state) {
            if (state is ImportProductsInitial ||
                state is ImportProductsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final qualities = _qualitiesFrom(state);
            final productTypes = _productTypesFrom(state);
            final entries = _entriesFrom(state);
            final selectedQualityId = _qualityIdFrom(state);
            final selectedProductTypeId = _productTypeIdFrom(state);
            final isSubmitting = state is ImportProductsSubmitting;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Progress bar (visible only while submitting) ───────────
                if (state is ImportProductsSubmitting)
                  _ProgressSection(state: state),

                // ── Quality selector ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Sifat'),
                    value: selectedQualityId,
                    items: qualities
                        .map(
                          (q) => DropdownMenuItem<int>(
                            value: q.id,
                            child: Text(
                              q.density != null
                                  ? '${q.qualityName} (${q.density})'
                                  : q.qualityName,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: isSubmitting
                        ? null
                        : (v) => context
                            .read<ImportProductsBloc>()
                            .add(ImportProductsQualityChanged(v)),
                    hint: const Text('Sifat tanlang (ixtiyoriy)'),
                  ),
                ),

                // ── Type selector ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Tur'),
                    value: selectedProductTypeId,
                    items: productTypes
                        .map(
                          (t) => DropdownMenuItem<int>(
                            value: t.id,
                            child: Text(t.type),
                          ),
                        )
                        .toList(),
                    onChanged: isSubmitting
                        ? null
                        : (v) => context
                            .read<ImportProductsBloc>()
                            .add(ImportProductsTypeChanged(v)),
                    hint: const Text('Tur tanlang (ixtiyoriy)'),
                  ),
                ),

                const Divider(height: 1, color: AppColors.divider),

                // ── Drop zone or parsed table ─────────────────────────────
                Expanded(
                  child: entries.isEmpty
                      ? _DropZone(
                          enabled: !isSubmitting,
                          onPickFiles: () => _pickAndParseFiles(context),
                          onFilesDropped: (files) =>
                              _handleDroppedFiles(context, files),
                        )
                      : _ImportTable(
                          entries: entries,
                          enabled: !isSubmitting,
                          onRemove: (i) => context
                              .read<ImportProductsBloc>()
                              .add(ImportProductsItemRemoved(i)),
                          onPickMoreFiles: () => _pickAndParseFiles(context),
                          onFilesDropped: (files) =>
                              _handleDroppedFiles(context, files),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── File picking & parsing ───────────────────────────────────────────────

  void _handleDroppedFiles(
    BuildContext context,
    List<DropItem> files,
  ) {
    final entries = files
        .map((f) => _parseFilename(f.name, f.path))
        .whereType<ParsedImportEntry>()
        .toList();
    if (entries.isNotEmpty && context.mounted) {
      context
          .read<ImportProductsBloc>()
          .add(ImportProductsEntriesAdded(entries));
    }
  }

  Future<void> _pickAndParseFiles(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: false,
    );

    if (result == null || !context.mounted) return;

    final entries = result.files
        .map((f) => _parseFilename(f.name, f.path))
        .whereType<ParsedImportEntry>()
        .toList();

    if (entries.isNotEmpty && context.mounted) {
      context
          .read<ImportProductsBloc>()
          .add(ImportProductsEntriesAdded(entries));
    }
  }

  /// Parses a filename of the form `{model}_..._...__{color}.ext`.
  ///
  /// - Everything before the FIRST `_` → product name
  /// - Everything after the LAST `_`  → color name
  /// - Returns `null` if the filename has no underscore (unrecognised format).
  ParsedImportEntry? _parseFilename(String filename, String? filePath) {
    final nameWithoutExt = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;

    final firstIdx = nameWithoutExt.indexOf('_');
    if (firstIdx < 0) {
      debugPrint('[Import] PARSE SKIP (no underscore): "$filename"');
      return null;
    }

    final lastIdx = nameWithoutExt.lastIndexOf('_');
    final productName = nameWithoutExt.substring(0, firstIdx).trim();
    final colorName = nameWithoutExt.substring(lastIdx + 1).trim();

    if (productName.isEmpty || colorName.isEmpty) {
      debugPrint('[Import] PARSE SKIP (empty name/color): "$filename" → product="$productName" color="$colorName"');
      return null;
    }

    debugPrint('[Import] PARSED: "$filename" → product="$productName" color="$colorName"');
    return ParsedImportEntry(
      productName: productName,
      colorName: colorName,
      imagePath: filePath,
    );
  }

  // ─── State accessors ─────────────────────────────────────────────────────

  List<ProductQualityEntity> _qualitiesFrom(ImportProductsState s) =>
      switch (s) {
        ImportProductsReady r => r.qualities,
        ImportProductsSubmitting r => r.qualities,
        ImportProductsFailure r => r.qualities,
        _ => const [],
      };

  List<ProductTypeEntity> _productTypesFrom(ImportProductsState s) =>
      switch (s) {
        ImportProductsReady r => r.productTypes,
        ImportProductsSubmitting r => r.productTypes,
        ImportProductsFailure r => r.productTypes,
        _ => const [],
      };

  List<ParsedImportEntry> _entriesFrom(ImportProductsState s) => switch (s) {
        ImportProductsReady r => r.entries,
        ImportProductsSubmitting r => r.entries,
        ImportProductsFailure r => r.entries,
        _ => const [],
      };

  int? _qualityIdFrom(ImportProductsState s) => switch (s) {
        ImportProductsReady r => r.selectedQualityId,
        ImportProductsSubmitting r => r.selectedQualityId,
        ImportProductsFailure r => r.selectedQualityId,
        _ => null,
      };

  int? _productTypeIdFrom(ImportProductsState s) => switch (s) {
        ImportProductsReady r => r.selectedProductTypeId,
        ImportProductsSubmitting r => r.selectedProductTypeId,
        ImportProductsFailure r => r.selectedProductTypeId,
        _ => null,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Drop zone widget
// ─────────────────────────────────────────────────────────────────────────────

class _DropZone extends StatefulWidget {
  const _DropZone({
    required this.enabled,
    required this.onPickFiles,
    required this.onFilesDropped,
  });

  final bool enabled;
  final VoidCallback onPickFiles;
  final void Function(List<DropItem> files) onFilesDropped;

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hovering = false;
  bool _dragging = false;

  bool get _highlighted => _hovering || _dragging;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        if (widget.enabled) widget.onFilesDropped(detail.files);
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: MouseRegion(
            cursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: GestureDetector(
              onTap: widget.enabled ? widget.onPickFiles : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                constraints: const BoxConstraints(maxWidth: 520),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 52, horizontal: 32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _highlighted
                        // ignore: deprecated_member_use
                        ? AppColors.primary.withOpacity(0.55)
                        // ignore: deprecated_member_use
                        : AppColors.primary.withOpacity(0.28),
                    width: _dragging ? 2.5 : 1.5,
                  ),
                  color: _highlighted
                      // ignore: deprecated_member_use
                      ? AppColors.primary.withOpacity(0.06)
                      // ignore: deprecated_member_use
                      : AppColors.primary.withOpacity(0.025),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _dragging
                          ? Icons.file_download_outlined
                          : Icons.upload_file_outlined,
                      size: 56,
                      // ignore: deprecated_member_use
                      color: AppColors.primary.withOpacity(_dragging ? 0.8 : 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _dragging
                          ? 'Fayl(lar)ni qo\'yib yuboring'
                          : 'Fayllarni bu yerga tashlang yoki bosing',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textPrimary,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Format: modelnom_misc_rang.jpg',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Import table widget
// ─────────────────────────────────────────────────────────────────────────────

class _ImportTable extends StatefulWidget {
  const _ImportTable({
    required this.entries,
    required this.enabled,
    required this.onRemove,
    required this.onPickMoreFiles,
    required this.onFilesDropped,
  });

  final List<ParsedImportEntry> entries;
  final bool enabled;
  final void Function(int index) onRemove;
  final VoidCallback onPickMoreFiles;
  final void Function(List<DropItem> files) onFilesDropped;

  @override
  State<_ImportTable> createState() => _ImportTableState();
}

class _ImportTableState extends State<_ImportTable> {
  bool _dragging = false;

  static const _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        if (widget.enabled) widget.onFilesDropped(detail.files);
      },
      child: Stack(
        children: [
          _buildTable(),
          // Drag-over overlay
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: AppColors.primary.withOpacity(0.08),
                    border: Border.all(
                      // ignore: deprecated_member_use
                      color: AppColors.primary.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.file_download_outlined,
                          size: 48,
                          // ignore: deprecated_member_use
                          color: AppColors.primary.withOpacity(0.7),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fayl(lar)ni qo\'yib yuboring',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            // ignore: deprecated_member_use
                            color: AppColors.primary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Header row ──────────────────────────────────────────────────
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Row(
            children: [
              Expanded(flex: 2, child: Text('Model', style: _headerStyle)),
              Expanded(flex: 2, child: Text('Rang', style: _headerStyle)),
              SizedBox(width: 44), // actions column
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),

        // ── Data rows ────────────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            itemCount: widget.entries.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final entry = widget.entries[index];
              return ColoredBox(
                color: AppColors.surface,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          entry.productName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            if (entry.imagePath != null) ...[
                              _LocalThumbnail(imagePath: entry.imagePath!),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                entry.colorName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        child: widget.enabled
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: AppColors.error,
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                onPressed: () => widget.onRemove(index),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ── Footer: add more files ────────────────────────────────────────
        const Divider(height: 1, color: AppColors.divider),
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(
                '${widget.entries.length} ta fayl tanlangan',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: widget.enabled ? widget.onPickMoreFiles : null,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('Fayl qo\'shish'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress section (shown above quality selector while submitting)
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.state});

  final ImportProductsSubmitting state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: AppColors.divider,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
                SizedBox(width: 10),
                Text(
                  'Yuklanmoqda...',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Local image thumbnail (for files selected by FilePicker)
// ─────────────────────────────────────────────────────────────────────────────

class _LocalThumbnail extends StatelessWidget {
  const _LocalThumbnail({required this.imagePath});

  final String imagePath;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        File(imagePath),
        width: _size,
        height: _size,
        fit: BoxFit.cover,
        cacheWidth: (_size * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: (_, __, ___) => Container(
          width: _size,
          height: _size,
          color: AppColors.divider,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
