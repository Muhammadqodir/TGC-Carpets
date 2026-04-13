import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../domain/entities/product_size_entity.dart';

/// A bottom sheet that loads sizes for a given [productTypeId] and lets
/// the user select one.  Returns the chosen [ProductSizeEntity] or null.
class ProductSizePickerSheet extends StatefulWidget {
  final int productTypeId;

  const ProductSizePickerSheet({super.key, required this.productTypeId});

  static Future<ProductSizeEntity?> show(
    BuildContext context, {
    required int productTypeId,
  }) {
    return showModalBottomSheet<ProductSizeEntity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProductSizePickerSheet(productTypeId: productTypeId),
    );
  }

  @override
  State<ProductSizePickerSheet> createState() => _ProductSizePickerSheetState();
}

class _ProductSizePickerSheetState extends State<ProductSizePickerSheet> {
  late Future<List<ProductSizeEntity>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<ProductRemoteDataSource>()
        .getProductSizes(productTypeId: widget.productTypeId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'O\'lchamni tanlang',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<ProductSizeEntity>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Ushbu turdagi o\'lchamlar topilmadi.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final sizes = snapshot.data!;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: sizes.map((size) {
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(size),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.primary.withValues(alpha: 0.06),
                      ),
                      child: Text(
                        size.dimensions,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
