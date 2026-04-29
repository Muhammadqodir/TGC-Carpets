import 'package:flutter/material.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';
import 'package:tgc_client/features/products_stock/domain/entities/stock_variant_entity.dart';

/// Adaptive stock variants data table - desktop shows all columns,
/// mobile merges product, quality, size, type into one column.
class StockVariantDataTable extends StatelessWidget {
  const StockVariantDataTable({
    super.key,
    required this.variants,
    required this.isLoadingMore,
    required this.scrollController,
  });

  final List<StockVariantEntity> variants;
  final bool isLoadingMore;
  final ScrollController scrollController;

  static const _desktopColumns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 56),
    AppTableColumn(label: 'Mahsulot', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Sifat', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Turi', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'O\'lcham', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Omborda', flex: 2),
    AppTableColumn(label: 'Band (buyurtma)', flex: 2),
    AppTableColumn(label: 'Bosh', flex: 2),
  ];

  static const _mobileColumns = <AppTableColumn>[
    AppTableColumn(label: 'Mahsulot', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Omborda', flex: 1, alignment: Alignment.center),
    AppTableColumn(label: 'Band', flex: 1, alignment: Alignment.center),
    AppTableColumn(label: 'Bosh', flex: 1, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppConstants.desktopBreakpoint;
        final columns = isMobile ? _mobileColumns : _desktopColumns;

        return AppDataTable<StockVariantEntity>(
          items: variants,
          columns: columns,
          scrollController: scrollController,
          isLoadingMore: isLoadingMore,
          cellBuilder: (context, variant, colIndex) => isMobile
              ? _buildMobileCell(context, variant, colIndex)
              : _buildDesktopCell(context, variant, colIndex),
        );
      },
    );
  }

  Widget _buildMobileCell(
      BuildContext context, StockVariantEntity variant, int colIndex) {
    switch (colIndex) {
      case 0: // Product (merged with quality, type, size)
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppThumbnail(imageUrl: variant.imageUrl, size: 44),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      BodyText(
                        text: variant.productName,
                        fontWeight: FontWeight.bold,
                      ),
                      const SizedBox(width: 6),
                      if (variant.size != null)
                        AppBadge(
                          label: variant.size!,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                  BodyText(text: "${variant.colorName.toUpperCase()} / ${variant.qualityName ?? '—'}"),
                ],
              ),
            ),
          ],
        );

      case 1: // Qty warehouse
        return _QuantityCell(
          value: variant.quantityWarehouse,
          highlightNonZero: false,
          highlightColor: AppColors.success,
          compact: true,
        );

      case 2: // Qty reserved
        return _QuantityCell(
          value: variant.quantityReserved,
          highlightNonZero: false,
          highlightColor: AppColors.warning,
          compact: true,
        );

      case 3: // Qty available (calculated)
        return _QuantityCell(
          value: variant.quantityWarehouse - variant.quantityReserved,
          highlightNonZero: true,
          highlightColor: AppColors.success,
          compact: true,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDesktopCell(
      BuildContext context, StockVariantEntity variant, int colIndex) {
    switch (colIndex) {
      case 0: // ID
        return Text(
          variant.id.toString(),
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        );

      case 1: // Product: thumbnail + name + color
        return Row(
          children: [
            AppThumbnail(imageUrl: variant.imageUrl, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    variant.productName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    variant.colorName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );

      case 2: // Quality
        return variant.qualityName != null
            ? AppBadge(
                label: variant.qualityName!, color: AppColors.primaryLight)
            : const Text('—');

      case 3: // Type
        return variant.typeName != null
            ? AppBadge(label: variant.typeName!, color: Colors.black87)
            : const Text('—');

      case 4: // Size
        return variant.size != null
            ? Text(
                variant.size!,
                style: Theme.of(context).textTheme.bodyMedium,
              )
            : const Text('—');

      case 5: // Qty warehouse
        return _QuantityCell(
          value: variant.quantityWarehouse,
          highlightNonZero: false,
          highlightColor: AppColors.success,
        );

      case 6: // Qty reserved
        return _QuantityCell(
          value: variant.quantityReserved,
          highlightNonZero: false,
          highlightColor: AppColors.warning,
        );

      case 7: // Qty available (calculated)
        return _QuantityCell(
          value: variant.quantityWarehouse - variant.quantityReserved,
          highlightNonZero: true,
          highlightColor: AppColors.warning,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------

class _QuantityCell extends StatelessWidget {
  const _QuantityCell({
    required this.value,
    required this.highlightNonZero,
    required this.highlightColor,
    this.compact = false,
  });

  final int value;
  final bool highlightNonZero;
  final Color highlightColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final highlight = highlightNonZero && value > 0;
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: highlight
          ? BoxDecoration(
              color: highlightColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Text(
        value.toString(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: highlight ? highlightColor : AppColors.textPrimary,
              fontSize: compact ? 13 : null,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
