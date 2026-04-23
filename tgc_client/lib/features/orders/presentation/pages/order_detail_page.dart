import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';
import 'package:tgc_client/core/ui/widgets/info_section.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/entities/order_item_entity.dart';
import 'args/order_detail_args.dart';

class OrderDetailPage extends StatelessWidget {
  final OrderDetailArgs args;

  const OrderDetailPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    final order = args.order;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('#${order.id} Buyurtma tafsilotlari'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          if (order.status == 'pending')
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Tahrirlash'),
              onPressed: () async {
                final updated = await context.pushNamed(
                  AppRoutes.editOrderName,
                  extra: order,
                );
                if (updated == true && context.mounted) {
                  context.pop(true);
                }
              },
            ),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OrderInfoSection(order: order),
            const SizedBox(height: 20),
            _OrderItemsTable(items: order.items),
          ],
        ),
      ),
    );
  }
}

class _OrderInfoSection extends StatelessWidget {
  final OrderEntity order;

  const _OrderInfoSection({required this.order});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (order.status) {
      'pending' => ('Kutilmoqda', AppColors.warning),
      'planned' => ('Rejalashtirilgan', AppColors.primary),
      'on_production' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'done' => ('Bajarildi', AppColors.success),
      'canceled' => ('Bekor qilindi', AppColors.error),
      _ => (order.status, AppColors.textSecondary),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Buyurtma ma\'lumotlari',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 12),
                AppBadge(label: statusLabel, color: statusColor),
              ],
            ),
            const SizedBox(height: 16),
            InfoSection(items: [
              InfoSectionItemData(label: "ID", value: '#${order.id}'),
              InfoSectionItemData(
                label: 'Sana',
                value: _formatDate(order.orderDate),
              ),
              InfoSectionItemData(label: 'Xodim', value: order.userName),
              InfoSectionItemData(
                label: 'Mijoz',
                value:
                    "${order.clientShopName ?? ''} / ${order.clientRegion ?? ''}",
              ),
              InfoSectionItemData(label: "Jami m²", value: "${order.totalSqm.toStringAsFixed(2)} m²"),
              InfoSectionItemData(label: "Jami dona", value: "${order.totalQuantity} ta"),
              InfoSectionItemData(label: "Ishlab chiqarildi", value: "${order.totalProducedQuantity} ta | ${(order.productionProgress * 100).toStringAsFixed(1)}%"),
              InfoSectionItemData(label: "Omborga kiritildi", value: "${order.totalWarehouseReceivedQuantity} ta | ${order.totalQuantity > 0 ? ((order.totalWarehouseReceivedQuantity / order.totalQuantity) * 100).toStringAsFixed(1) : '0.0'}%"),
              InfoSectionItemData(label: "Yuborildi", value: "${order.totalShippedQuantity} ta | ${order.totalQuantity > 0 ? ((order.totalShippedQuantity / order.totalQuantity) * 100).toStringAsFixed(1) : '0.0'}%"),

            ]),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Izoh: ',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Expanded(
                    child: Text(
                      order.notes!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _OrderItemsTable extends StatelessWidget {
  final List<OrderItemEntity> items;

  const _OrderItemsTable({required this.items});

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
              'Mahsulotlar ro\'yxati',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          LayoutBuilder(builder: (context, constraints) {
            final tableWidth =
                constraints.maxWidth < 800 ? 800 : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth.toDouble(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                              width: 40, child: Text('#', style: labelStyle)),
                          Expanded(
                              flex: 3,
                              child: Text('Mahsulot', style: labelStyle)),
                          Expanded(
                              flex: 4,
                              child: Text('Sifat / Tur', style: labelStyle)),
                          Expanded(
                              flex: 2,
                              child: Text('O\'lcham', style: labelStyle)),
                          SizedBox(
                            width: 60,
                            child: Text('Soni', style: labelStyle),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text('Tayyor', style: labelStyle),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text('Yetkazildi', style: labelStyle),
                          ),
                          SizedBox(
                            width: 100,
                            child: Text(
                              'Jami m²',
                              style: labelStyle,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    // Rows
                    ...items.asMap().entries.expand((entry) sync* {
                      yield _buildRow(context, entry.key, entry.value);
                      if (entry.key < items.length - 1) {
                        yield const Divider(
                            height: 1, color: AppColors.divider);
                      }
                    }),
                    const Divider(height: 1, color: AppColors.divider),
                    // Totals footer
                    Builder(builder: (context) {
                      final totalQty =
                          items.fold(0, (sum, i) => sum + i.quantity);
                      final totalSqm = items.fold(0.0, (sum, i) {
                        if (i.sizeLength == null || i.sizeWidth == null)
                          return sum;
                        return sum +
                            i.sizeLength! * i.sizeWidth! * i.quantity / 10000.0;
                      });
                      final footerStyle =
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              );
                      return Container(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            const SizedBox(width: 40),
                            Expanded(
                              flex: 3,
                              child: Text('Jami', style: footerStyle),
                            ),
                            const Expanded(flex: 2, child: SizedBox.shrink()),
                            const Expanded(flex: 2, child: SizedBox.shrink()),
                            const Expanded(flex: 2, child: SizedBox.shrink()),
                            const Expanded(flex: 2, child: SizedBox.shrink()),
                            SizedBox(
                              width: 60,
                              child: Text('$totalQty dona',
                                  textAlign: TextAlign.start,
                                  style: footerStyle),
                            ),
                            const SizedBox(width: 120),
                            SizedBox(
                              width: 100,
                              child: Text('${totalSqm.toStringAsFixed(2)} m²',
                                  textAlign: TextAlign.end, style: footerStyle),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index, OrderItemEntity item) {
    final sqm = item.sizeLength != null && item.sizeWidth != null
        ? item.sizeLength! * item.sizeWidth! * item.quantity / 10000.0
        : 0.0;
    final perUnitSqm = item.sizeLength != null && item.sizeWidth != null
        ? item.sizeLength! * item.sizeWidth! / 10000.0
        : 0.0;
    return Container(
      color: index.isOdd ? AppColors.surface.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: BodyText(text: '${index + 1}'),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                AppThumbnail(
                  imageUrl: item.colorImageUrl,
                  size: 32,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BodyText(
                        text: item.productName,
                      ),
                      SubBodyText(text: item.colorName?.toUpperCase() ?? '—'),
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              "${item.qualityName ?? '—'} / ${item.productTypeName ?? '—'}",
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.sizeLength != null && item.sizeWidth != null
                      ? '${item.sizeLength}x${item.sizeWidth}'
                      : '—',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.sizeLength != null && item.sizeWidth != null
                      ? '${perUnitSqm.toStringAsFixed(2)} m²'
                      : '—',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(
            width: 60,
            child: BodyText(
              text: '${item.plannedQuantity}',
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            width: 60,
            child: BodyText(
              text: '${item.producedQuantity}',
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            width: 60,
            child: BodyText(
              text: '${item.shippedQuantity}',
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(
            width: 100,
            child: BodyText(
              text: sqm > 0 ? '${sqm.toStringAsFixed(2)} m²' : '—',
              fontWeight: FontWeight.bold,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
