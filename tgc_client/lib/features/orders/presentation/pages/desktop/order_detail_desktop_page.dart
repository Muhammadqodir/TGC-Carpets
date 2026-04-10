import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/order_entity.dart';
import '../../../domain/entities/order_item_entity.dart';

class OrderDetailDesktopPage extends StatelessWidget {
  final OrderEntity order;

  const OrderDetailDesktopPage({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DesktopInfoSection(order: order),
            const SizedBox(height: 20),
            _DesktopItemsTable(items: order.items),
          ],
        ),
      ),
    );
  }
}

class _DesktopInfoSection extends StatelessWidget {
  final OrderEntity order;

  const _DesktopInfoSection({required this.order});

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (order.status) {
      'pending'       => ('Kutilmoqda', AppColors.warning),
      'on_production' => ('Ishlab chiqarilmoqda', AppColors.primaryLight),
      'done'          => ('Bajarildi', AppColors.success),
      'canceled'      => ('Bekor qilindi', AppColors.error),
      _               => (order.status, AppColors.textSecondary),
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withAlpha(100)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 40,
              runSpacing: 12,
              children: [
                _InfoItem(label: 'ID', value: '#${order.id}'),
                _InfoItem(
                  label: 'Sana',
                  value: _formatDate(order.orderDate),
                ),
                _InfoItem(label: 'Xodim', value: order.userName),
                if (order.clientShopName != null)
                  _InfoItem(label: 'Mijoz', value: order.clientShopName!),
                if (order.clientPhone != null)
                  _InfoItem(label: 'Telefon', value: order.clientPhone!),
                _InfoItem(
                    label: 'Mahsulotlar', value: '${order.items.length} ta'),
                _InfoItem(
                    label: 'Jami dona', value: '${order.totalQuantity}'),
                _InfoItem(
                    label: 'Jami m²',
                    value: '${order.totalSqm.toStringAsFixed(2)} m²'),
              ],
            ),
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

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class _DesktopItemsTable extends StatelessWidget {
  final List<OrderItemEntity> items;

  const _DesktopItemsTable({required this.items});

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
          // Header
          Container(
            color: AppColors.primary.withValues(alpha: 0.04),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(width: 52, child: Text('#', style: labelStyle)),
                Expanded(flex: 3, child: Text('Mahsulot', style: labelStyle)),
                Expanded(flex: 2, child: Text('Rang', style: labelStyle)),
                Expanded(flex: 1, child: Text('O\'lcham', style: labelStyle)),
                Expanded(flex: 2, child: Text('SKU', style: labelStyle)),
                SizedBox(width: 80, child: Text('Dona', style: labelStyle, textAlign: TextAlign.center)),
                SizedBox(width: 100, child: Text('m²', style: labelStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Rows
          ...items.asMap().entries.expand((entry) sync* {
            yield _buildRow(context, entry.key, entry.value);
            if (entry.key < items.length - 1) {
              yield const Divider(height: 1, color: AppColors.divider);
            }
          }),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, int index, OrderItemEntity item) {
    final sqm = item.sizeLength != null && item.sizeWidth != null
        ? item.sizeLength! * item.sizeWidth! * item.quantity / 10000.0
        : 0.0;
    return Container(
      color: index.isOdd
          ? AppColors.surface.withValues(alpha: 0.5)
          : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              item.productName,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.colorName ?? '—',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              item.sizeLength != null && item.sizeWidth != null
                  ? '${item.sizeLength}x${item.sizeWidth}'
                  : '—',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              item.variantSku ?? '—',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              sqm > 0 ? '${sqm.toStringAsFixed(2)} m²' : '—',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
