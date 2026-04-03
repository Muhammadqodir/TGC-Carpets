import 'package:flutter/material.dart';
import 'package:tgc_client/core/extensions/amount.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import '../../domain/entities/sale_entity.dart';

class SaleCard extends StatelessWidget {
  final SaleEntity sale;

  const SaleCard({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sale.clientShopName ?? 'Noma\'lum mijoz',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.calendar_today_outlined,
                    size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _formatDate(sale.saleDate),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            if (sale.items.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '${sale.items.length} ta mahsulot',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    '\$ ${sale.totalAmount.toCurrencyString()}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
