import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/pages/pdf_viewer.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';

import '../../domain/entities/warehouse_document_entity.dart';

/// Warehouse Documents data table that wraps the generic [AppDataTable].
class WarehouseDocumentTable extends StatelessWidget {
  const WarehouseDocumentTable({
    super.key,
    required this.documents,
    required this.isLoadingMore,
    required this.scrollController,
  });

  final List<WarehouseDocumentEntity> documents;
  final bool isLoadingMore;
  final ScrollController scrollController;

  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 68, alignment: Alignment.center),
    AppTableColumn(label: 'Sana', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Foydalanuvchi', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Turi', flex: 1, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Hajm', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Mijoz', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'PDF', fixedWidth: 80),
  ];

  @override
  Widget build(BuildContext context) {
    return AppDataTable<WarehouseDocumentEntity>(
      items: documents,
      columns: _columns,
      scrollController: scrollController,
      isLoadingMore: isLoadingMore,
      cellBuilder: (context, document, colIndex) =>
          _buildCell(context, document, colIndex),
    );
  }

  Widget _buildCell(
      BuildContext context, WarehouseDocumentEntity document, int colIndex) {
    switch (colIndex) {
      case 0: // ID
        return Padding(
          padding: const EdgeInsets.all(0),
          child: Text(
            '${document.id}',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        );

      case 1: // Date
        return Text(
          _formatDateTime(document.documentDate),
          style: Theme.of(context).textTheme.bodyMedium,
        );

      case 2: // User
        return Row(
          children: [
            const Icon(Icons.person_outline,
                size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                document.userName,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

      case 3: // Type
        return _TypeChip(type: document.type);

      case 4: // Volume
        return _VolumeCell(document: document);

      case 5: // Source
        return document.sourceType != null
            ? Row(
                children: [
                  const Icon(Icons.category_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _sourceTypeLabel(document.sourceType!),
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Text(
                '—',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              );

      case 6: // PDF
        return Center(
          child: document.pdfUrl != null
              ? IconButton(
                  onPressed: () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => PdfViewerPage(
                        pdfUrl: document.pdfUrl!,
                        title: 'Hujjat №${document.id}',
                      ),
                    ),
                  ),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedPdf01,
                    color: AppColors.error,
                  ),
                  tooltip: 'PDF ko\'rish',
                )
              : const Icon(
                  Icons.remove,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  String _sourceTypeLabel(String sourceType) => switch (sourceType) {
        'production' => 'Ishlab chiqarish',
        'sale' => 'Sotuv',
        'other' => 'Boshqa',
        _ => sourceType,
      };

  String _formatDateTime(DateTime date) {
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} $timeStr';
  }
}

class _TypeChip extends StatelessWidget {
  final String type;

  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'in' => ('Kirim', AppColors.success),
      'out' => ('Chiqim', AppColors.error),
      'return' => ('Qaytish', AppColors.accent),
      _ => (type, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _VolumeCell extends StatelessWidget {
  final WarehouseDocumentEntity document;

  const _VolumeCell({required this.document});

  @override
  Widget build(BuildContext context) {
    // Calculate total pieces and square meters
    int totalPieces = 0;
    double totalM2 = 0;

    for (final item in document.items) {
      if (item.productUnit == 'piece') {
        totalPieces += item.quantity;
      } else if (item.productUnit == 'm2') {
        totalM2 += item.quantity;
      }
    }

    final parts = <String>[];
    if (totalPieces > 0) parts.add('$totalPieces dona');
    if (totalM2 > 0) parts.add('${totalM2.toStringAsFixed(1)} m²');

    if (parts.isEmpty) {
      return Text(
        '—',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.join(' • '),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          '${document.items.length} mahsulot',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(),
        ),
      ],
    );
  }
}
