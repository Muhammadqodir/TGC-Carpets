import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_thumbnail.dart';
import '../../domain/entities/available_order_item_entity.dart';

/// Modal dialog for selecting order items to add to a production batch.
class AddFromOrderModal extends StatefulWidget {
  final List<AvailableOrderItemEntity> availableItems;

  const AddFromOrderModal({super.key, required this.availableItems});

  @override
  State<AddFromOrderModal> createState() => _AddFromOrderModalState();
}

class _AddFromOrderModalState extends State<AddFromOrderModal> {
  final Map<int, int> _selectedQuantities = {}; // orderItemId -> qty
  final Map<int, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleItem(AvailableOrderItemEntity item) {
    setState(() {
      if (_selectedQuantities.containsKey(item.orderItemId)) {
        _selectedQuantities.remove(item.orderItemId);
        _controllers[item.orderItemId]?.clear();
      } else {
        _selectedQuantities[item.orderItemId] = item.remainingQuantity;
        _controllers.putIfAbsent(
          item.orderItemId,
          () => TextEditingController(
              text: item.remainingQuantity.toString()),
        );
        _controllers[item.orderItemId]!.text =
            item.remainingQuantity.toString();
      }
    });
  }

  void _fillAll() {
    setState(() {
      for (final item in widget.availableItems) {
        _selectedQuantities[item.orderItemId] = item.remainingQuantity;
        _controllers.putIfAbsent(
          item.orderItemId,
          () => TextEditingController(),
        );
        _controllers[item.orderItemId]!.text =
            item.remainingQuantity.toString();
      }
    });
  }

  void _confirm() {
    final result = <Map<String, dynamic>>[];
    for (final entry in _selectedQuantities.entries) {
      if (entry.value > 0) {
        final item = widget.availableItems
            .firstWhere((i) => i.orderItemId == entry.key);
        result.add({
          'source_type': 'order_item',
          'source_order_item_id': item.orderItemId,
          'product_variant_id': item.variantId,
          'planned_quantity': entry.value,
          // Extra fields for UI display
          '_display': item,
        });
      }
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.availableItems;

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Buyurtmadan qo\'shish',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _fillAll,
                    child: const Text('Hammasini tanlash'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Table header
            Container(
              color: AppColors.primary.withValues(alpha: 0.04),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 40), // checkbox
                  Expanded(
                      flex: 1,
                      child: Text('Buyurtma',
                          style: _headerStyle(context))),
                  Expanded(
                      flex: 3,
                      child: Text('Mahsulot',
                          style: _headerStyle(context))),
                  SizedBox(
                      width: 80,
                      child: Text('Buyurtma',
                          textAlign: TextAlign.center,
                          style: _headerStyle(context))),
                  SizedBox(
                      width: 80,
                      child: Text('Reja',
                          textAlign: TextAlign.center,
                          style: _headerStyle(context))),
                  SizedBox(
                      width: 80,
                      child: Text('Qoldiq',
                          textAlign: TextAlign.center,
                          style: _headerStyle(context))),
                  SizedBox(
                      width: 100,
                      child: Text('Miqdor',
                          textAlign: TextAlign.center,
                          style: _headerStyle(context))),
                ],
              ),
            ),
            const Divider(height: 1),
            // Items
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('Mavjud buyurtma mahsulotlari topilmadi'))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = _selectedQuantities
                            .containsKey(item.orderItemId);

                        _controllers.putIfAbsent(
                          item.orderItemId,
                          () => TextEditingController(),
                        );

                        return Container(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.04)
                              : null,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (_) => _toggleItem(item),
                                ),
                              ),
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#${item.orderNumber}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    if (item.clientShopName != null)
                                      Text(
                                        item.clientShopName!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                                color:
                                                    AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    AppThumbnail(
                                      imageUrl: item.colorImageUrl,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            [
                                              if (item.colorName != null)
                                                item.colorName!,
                                              if (item.sizeLength != null &&
                                                  item.sizeWidth != null)
                                                '${item.sizeLength}x${item.sizeWidth}',
                                            ].join(' / '),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color: AppColors
                                                        .textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  '${item.orderedQuantity}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium,
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  '${item.plannedQuantity}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium,
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  '${item.remainingQuantity}',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.success),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: isSelected
                                    ? SizedBox(
                                        height: 36,
                                        child: TextFormField(
                                          controller: _controllers[
                                              item.orderItemId],
                                          keyboardType:
                                              TextInputType.number,
                                          textAlign: TextAlign.center,
                                          decoration:
                                              const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8),
                                          ),
                                          onChanged: (val) {
                                            final qty =
                                                int.tryParse(val) ?? 0;
                                            if (qty > 0 &&
                                                qty <=
                                                    item
                                                        .remainingQuantity) {
                                              _selectedQuantities[
                                                      item.orderItemId] =
                                                  qty;
                                            }
                                          },
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${_selectedQuantities.length} ta tanlandi',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Bekor qilish'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed:
                        _selectedQuantities.isNotEmpty ? _confirm : null,
                    child: const Text('Qo\'shish'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle? _headerStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          );
}
