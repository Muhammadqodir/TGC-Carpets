import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/order_item_entity.dart';

class OrderDetailMobilePage extends StatelessWidget {
  final OrderEntity order;

  const OrderDetailMobilePage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('#${order.id} Buyurtma'),
        titleSpacing: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            strokeWidth: 2,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (order.status == 'pending')
            IconButton(
              tooltip: 'Tahrirlash',
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedEdit01,
                strokeWidth: 2,
              ),
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
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _OrderInfoCard(order: order),
            const SizedBox(height: 12),
            _OrderItemsCard(order: order),
          ],
        ),
      ),
    );
  }
}

class _OrderInfoCard extends StatelessWidget {
  final OrderEntity order;

  const _OrderInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Buyurtma ma\'lumotlari',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                _StatusBadge(status: order.status),
              ],
            ),
            const Divider(height: 20),
            _InfoRow(
              icon: HugeIcons.strokeRoundedTag01,
              label: 'ID',
              value: '#${order.id}',
            ),
            _InfoRow(
              icon: HugeIcons.strokeRoundedCalendar01,
              label: 'Sana',
              value: _formatDate(order.orderDate),
            ),
            _InfoRow(
              icon: HugeIcons.strokeRoundedUser,
              label: 'Xodim',
              value: order.userName,
            ),
            if (order.clientShopName != null)
              _InfoRow(
                icon: HugeIcons.strokeRoundedStore03,
                label: 'Mijoz',
                value: order.clientShopName! +
                    (order.clientRegion != null
                        ? ' / ${order.clientRegion!}'
                        : ''),
              ),
            if (order.clientPhone != null)
              _InfoRow(
                icon: HugeIcons.strokeRoundedCall,
                label: 'Telefon',
                value: order.clientPhone!,
              ),
            if (order.notes != null && order.notes!.isNotEmpty)
              _InfoRow(
                icon: HugeIcons.strokeRoundedNote01,
                label: 'Izoh',
                value: order.notes!,
              ),
            const SizedBox(height: 4),
            const Divider(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Mahsulotlar',
                    value: '${order.items.length} ta',
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Jami dona',
                    value: '${order.totalQuantity}',
                  ),
                ),
                Expanded(
                  child: _StatTile(
                    label: 'Jami m²',
                    value: '${order.totalSqm.toStringAsFixed(2)} m²',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

class _OrderItemsCard extends StatelessWidget {
  final OrderEntity order;

  const _OrderItemsCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mahsulotlar ro\'yxati',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            ...order.items.asMap().entries.map(
                  (entry) => _OrderItemTile(
                    item: entry.value,
                    index: entry.key + 1,
                    isLast: entry.key == order.items.length - 1,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final OrderItemEntity item;
  final int index;
  final bool isLast;

  const _OrderItemTile({
    required this.item,
    required this.index,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Container(
              //   width: 28,
              //   height: 28,
              //   decoration: BoxDecoration(
              //     color: AppColors.primary.withAlpha(20),
              //     borderRadius: BorderRadius.circular(6),
              //   ),
              //   alignment: Alignment.center,
              //   child: Text(
              //     '$index',
              //     style: const TextStyle(
              //       fontSize: 12,
              //       fontWeight: FontWeight.w600,
              //       color: AppColors.primary,
              //     ),
              //   ),
              // ),
              // const SizedBox(width: 12),
              AppThumbnail(
                imageUrl: item.colorImageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (item.colorName != null || item.sizeLength != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _variantLabel(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    if (item.variantSku != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'SKU: ${item.variantSku}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.quantity} dona',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                  ),
                  if (item.sizeLength != null && item.sizeWidth != null)
                    Text(
                      '${(item.sizeLength! * item.sizeWidth! * item.quantity / 10000.0).toStringAsFixed(2)} m²',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1),
      ],
    );
  }

  String _variantLabel() {
    final parts = <String>[];
    if (item.colorName != null) parts.add(item.colorName!.toUpperCase());
    if (item.sizeLength != null && item.sizeWidth != null) {
      parts.add('${item.sizeLength}x${item.sizeWidth}');
    }
    return parts.join(' / ');
  }
}

class _InfoRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: icon,
            size: 16,
            color: AppColors.textSecondary,
            strokeWidth: 2,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'pending'       => ('Kutilmoqda', AppColors.warning),
      'planned'       => ('Rejalashtirilgan', AppColors.primary),
      'on_production' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'done'          => ('Bajarildi', AppColors.success),
      'canceled'      => ('Bekor qilindi', AppColors.error),
      _               => (status, AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
