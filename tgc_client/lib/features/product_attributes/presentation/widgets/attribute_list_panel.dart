import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// A reusable list panel showing a titled list of attribute items.
/// Each item has an edit and delete action.
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
    this.emptyMessage = 'Ma\'lumot topilmadi.',
  });

  final String title;
  final List<T> items;
  final String Function(T item) itemLabel;
  final String? Function(T item) itemSubtitle;
  final VoidCallback onAdd;
  final void Function(T item) onEdit;

  /// Called when the delete icon is pressed.
  /// The callback is responsible for any confirmation dialogs and the actual
  /// delete logic (including replacement if needed).
  final Future<void> Function(T item) onDelete;

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
                    return ListTile(
                      dense: true,
                      title: Text(
                        itemLabel(item),
                        style: Theme.of(context).textTheme.bodyMedium,
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
