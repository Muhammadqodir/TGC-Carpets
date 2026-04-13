import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_bloc.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_event.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_state.dart';
import '../../domain/entities/stock_variant_entity.dart';

/// Mobile list view for the Products Stock feature.
class ProductsStockMobilePage extends StatefulWidget {
  const ProductsStockMobilePage({super.key});

  @override
  State<ProductsStockMobilePage> createState() =>
      _ProductsStockMobilePageState();
}

class _ProductsStockMobilePageState extends State<ProductsStockMobilePage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context
          .read<ProductsStockBloc>()
          .add(const ProductsStockNextPageRequested());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mahsulotlar qoldig\'i'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Yangilash',
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => context
                .read<ProductsStockBloc>()
                .add(const ProductsStockRefreshRequested()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<ProductsStockBloc, ProductsStockState>(
        builder: (context, state) {
          if (state is ProductsStockLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ProductsStockError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context
                        .read<ProductsStockBloc>()
                        .add(const ProductsStockRefreshRequested()),
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          if (state is ProductsStockLoaded) {
            if (state.variants.isEmpty) {
              return const Center(
                child: Text(
                  'Omborda mahsulot topilmadi',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => context
                  .read<ProductsStockBloc>()
                  .add(const ProductsStockRefreshRequested()),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount:
                    state.variants.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index >= state.variants.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return _StockVariantCard(variant: state.variants[index]);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StockVariantCard extends StatelessWidget {
  const _StockVariantCard({required this.variant});

  final StockVariantEntity variant;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppThumbnail(imageUrl: variant.imageUrl, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          variant.productName,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '#${variant.id}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    variant.colorName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (variant.typeName != null)
                        AppBadge(
                            label: variant.typeName!, color: Colors.black87),
                      if (variant.qualityName != null)
                        AppBadge(
                            label: variant.qualityName!,
                            color: AppColors.primaryLight),
                      if (variant.size != null)
                        AppBadge(
                            label: variant.size!,
                            color: AppColors.textSecondary),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _StockChip(
                        label: 'Band',
                        value: variant.quantityReserved,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 10),
                      _StockChip(
                        label: 'Ombor',
                        value: variant.quantityWarehouse,
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockChip extends StatelessWidget {
  const _StockChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          Text(
            value.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
