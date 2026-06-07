import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// A reusable list panel showing a titled list of attribute items.
/// Each item has an edit, optional archive-toggle, and delete action.
class AttributeListPanel<T> extends StatelessWidget {
  const AttributeListPanel({
    super.key,
    required this.title,
    required this.items,
    required this.itemLabel,
    required this.itemSubtitle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    this.isArchived,
    this.onArchiveToggle,
    this.emptyMessage = 'Ma\'lumot topilmadi.',
  });

  final String title;
  final List<T> items;
  final String Function(T item) itemLabel;
  final String? Function(T item) itemSubtitle;
  final VoidCallback onAdd;
  final void Function(T item) onEdit;
  final Future<void> Function(T item) onDelete;

  /// If provided, enables the archive-toggle button for each item.
  final bool Function(T item)? isArchived;
  final void Function(T item, bool archive)? onArchiveToggle;

  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PanelHeader(title: title, onAdd: onAdd),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final subtitle = itemSubtitle(item);
                    final archived = isArchived?.call(item) ?? false;

                    return Opacity(
                      opacity: archived ? 0.55 : 1.0,
                      child: ListTile(
                        dense: true,
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                itemLabel(item),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      decoration: archived ? TextDecoration.lineThrough : null,
                                      color: archived ? AppColors.textSecondary : null,
                                    ),
                              ),
                            ),
                            if (archived)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Arxiv',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 10,
                                      ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: subtitle != null
                            ? Text(
                                subtitle,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onArchiveToggle != null)
                              IconButton(
                                icon: Icon(
                                  archived
                                      ? Icons.unarchive_outlined
                                      : Icons.archive_outlined,
                                  size: 18,
                                ),
                                color: archived ? AppColors.success : AppColors.textSecondary,
                                tooltip: archived ? 'Arxivdan chiqarish' : 'Arxivlash',
                                onPressed: () => onArchiveToggle!(item, !archived),
                              ),
                            if (!archived)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                color: AppColors.primary,
                                tooltip: 'Tahrirlash',
                                onPressed: () => onEdit(item),
                              ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              color: AppColors.error,
                              tooltip: 'O\'chirish',
                              onPressed: () => onDelete(item),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.onAdd});

  final String title;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Qo\'shish'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}
