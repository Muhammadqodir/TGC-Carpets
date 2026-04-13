import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/pages/pdf_viewer.dart';
import '../../domain/entities/warehouse_document_entity.dart';

class WarehouseDocumentCard extends StatelessWidget {
  final WarehouseDocumentEntity document;
  final VoidCallback? onTap;

  const WarehouseDocumentCard({super.key, required this.document, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap ??
            (document.pdfUrl != null
                ? () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        builder: (_) => PdfViewerPage(
                          pdfUrl: document.pdfUrl!,
                          title: 'Hujjat №${document.id}',
                        ),
                      ),
                    )
                : null),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '#${document.id}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                  ),
                  const SizedBox(width: 10),
                  _TypeBadge(type: document.type),
                  const Spacer(),
                  if (document.pdfUrl != null)
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedPdf01,
                      size: 18,
                      color: AppColors.error,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    _formatDateTime(document.documentDate),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      document.userName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (document.notes != null && document.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.notes_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        document.notes!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _VolumeInfo(document: document),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} $timeStr';
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'in' => ('Kirim', AppColors.success),
      'out' => ('Chiqim', AppColors.error),
      'return' => ('Qaytish', AppColors.accent),
      _ => (type, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

class _VolumeInfo extends StatelessWidget {
  final WarehouseDocumentEntity document;

  const _VolumeInfo({required this.document});

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hajm',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            if (totalPieces > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '$totalPieces dona',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            if (totalM2 > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.square_foot,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${totalM2.toStringAsFixed(1)} m²',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${document.items.length} mahsulot',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
