import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';

/// Column definition for [AppDataTable].
class AppTableColumn {
  const AppTableColumn({
    required this.label,
    this.sortKey,
    this.alignment = Alignment.center,
    this.flex,
    this.fixedWidth,
  });

  /// Column header text.
  final String label;

  /// A unique key used to identify this column for sorting.
  /// If null the column is not sortable.
  final String? sortKey;

  /// Explicit cell alignment.
  final Alignment alignment;

  /// Flex share when [fixedWidth] is null.
  final int? flex;

  /// Fixed pixel width (overrides [flex]).
  final double? fixedWidth;
}

/// Generic sortable data table with infinite-scroll support.
/// Reusable across all features — supply column definitions and a
/// [cellBuilder] that maps `(item, columnIndex) → Widget`.
///
/// Usage:
/// ```dart
/// AppDataTable<ProductEntity>(
///   items: state.products,
///   columns: _columns,
///   cellBuilder: (context, product, col) => ...,
///   scrollController: _scrollController,
///   activeSortKey: _sortKey,
///   sortAscending: _sortAsc,
///   onSort: (key, asc) { ... },
/// )
/// ```
class AppDataTable<T> extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.items,
    required this.columns,
    required this.cellBuilder,
    required this.scrollController,
    this.isLoadingMore = false,
    this.activeSortKey,
    this.sortAscending = true,
    this.onSort,
  });

  final List<T> items;
  final List<AppTableColumn> columns;

  /// Return the widget for [item] at the given [columnIndex].
  final Widget Function(BuildContext context, T item, int columnIndex)
      cellBuilder;

  final ScrollController scrollController;
  final bool isLoadingMore;

  /// The [AppTableColumn.sortKey] of the currently sorted column.
  final String? activeSortKey;
  final bool sortAscending;

  /// Called when the user taps a sortable column header.
  final void Function(String sortKey, bool ascending)? onSort;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AppTableHeader(
          columns: columns,
          activeSortKey: activeSortKey,
          sortAscending: sortAscending,
          onSort: onSort,
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: items.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _AppTableRow(
                isEven: index.isEven,
                columns: columns,
                cellBuilder: (colIndex) =>
                    cellBuilder(context, items[index], colIndex),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header row
// ---------------------------------------------------------------------------

class _AppTableHeader extends StatelessWidget {
  const _AppTableHeader({
    required this.columns,
    required this.activeSortKey,
    required this.sortAscending,
    required this.onSort,
  });

  final List<AppTableColumn> columns;
  final String? activeSortKey;
  final bool sortAscending;
  final void Function(String, bool)? onSort;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (var col in columns)
            _AppTableCellWrapper(
              column: col,
              child: _sortableHeader(context, col),
            ),
        ],
      ),
    );
  }

  Widget _sortableHeader(BuildContext context, AppTableColumn col) {
    final isActive =
        col.sortKey != null && col.sortKey == activeSortKey;

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: col.sortKey == null || onSort == null
          ? null
          : () => onSort!(
                col.sortKey!,
                isActive ? !sortAscending : true,
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              col.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
            if (col.sortKey != null) ...[
              const SizedBox(width: 2),
              Icon(
                isActive
                    ? (sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward)
                    : Icons.unfold_more,
                size: 14,
                color:
                    isActive ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data row
// ---------------------------------------------------------------------------

class _AppTableRow extends StatelessWidget {
  const _AppTableRow({
    required this.isEven,
    required this.columns,
    required this.cellBuilder,
  });

  final bool isEven;
  final List<AppTableColumn> columns;
  final Widget Function(int columnIndex) cellBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? AppColors.surface : AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            _AppTableCellWrapper(
              column: columns[i],
              child: cellBuilder(i),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cell layout helper
// ---------------------------------------------------------------------------

class _AppTableCellWrapper extends StatelessWidget {
  const _AppTableCellWrapper({
    required this.column,
    required this.child,
  });

  final AppTableColumn column;
  final Widget child;

  @override
  Widget build(BuildContext context) {

    if (column.fixedWidth != null) {
      return SizedBox(
        width: column.fixedWidth,
        child: Align(alignment: column.alignment, child: child),
      );
    }

    return Expanded(
      flex: column.flex ?? 1,
      child: Align(alignment: column.alignment, child: child),
    );
  }
}
