import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/pages/pdf_viewer.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';

import '../../domain/entities/warehouse_document_entity.dart';

/// Adaptive warehouse documents table with desktop and mobile layouts.
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
    AppTableColumn(label: 'Izoh', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'PDF', fixedWidth: 80),
  ];

  static const _columnsMobile = <AppTableColumn>[
    AppTableColumn(label: 'Hujjat', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Hajm', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: '', fixedWidth: 40, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop =
            constraints.maxWidth >= AppConstants.desktopBreakpoint;
        final columns = isDesktop ? _columns : _columnsMobile;

        return AppDataTable<WarehouseDocumentEntity>(
          items: documents,
          columns: columns,
          scrollController: scrollController,
          isLoadingMore: isLoadingMore,
          cellBuilder: (context, document, colIndex) =>
              _buildCell(context, document, colIndex, isDesktop),
        );
      },
    );
  }

  Widget _buildCell(BuildContext context, WarehouseDocumentEntity document,
      int colIndex, bool isDesktop) {
    if (!isDesktop) {
      return _buildMobileCell(context, document, colIndex);
    }
    return _buildDesktopCell(context, document, colIndex);
  }

  Widget _buildDesktopCell(
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

      case 5: // Notes
        return document.notes != null && document.notes!.isNotEmpty
            ? Text(
                document.notes!,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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

  Widget _buildMobileCell(
      BuildContext context, WarehouseDocumentEntity document, int colIndex) {
    switch (colIndex) {
      case 0: // Document info
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                _TypeChip(type: document.type),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(document.documentDate),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              document.userName,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );

      case 1: // Volume
        return _VolumeCell(document: document);

      case 2: // PDF icon
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
                    size: 20,
                  ),
                )
              : const SizedBox.shrink(),
        );

      default:
        return const SizedBox.shrink();
    }
  }

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

    return AppBadge(
      label: label,
      color: color,
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
    double totalSqm = 0;

    for (final item in document.items) {
      totalPieces += item.quantity;
      // Calculate sqm only if dimensions are available (length and width in cm)
      if (item.length != null && item.width != null) {
        totalSqm += item.quantity * item.length! * item.width! / 10000.0;
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${totalSqm.toStringAsFixed(2)} m²',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          "${totalPieces} dona",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(),
        ),
      ],
    );
  }
}
