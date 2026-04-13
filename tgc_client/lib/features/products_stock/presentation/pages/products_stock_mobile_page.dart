import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/appbar_search.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_bloc.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_event.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_state.dart';
import 'package:tgc_client/features/products_stock/presentation/widgets/stock_variant_card.dart';

/// Mobile list view for the Products Stock feature.
class ProductsStockMobilePage extends StatefulWidget {
  const ProductsStockMobilePage({super.key});

  @override
  State<ProductsStockMobilePage> createState() =>
      _ProductsStockMobilePageState();
}

class _ProductsStockMobilePageState extends State<ProductsStockMobilePage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarSearch(
        title: const Text('Mahsulotlar qoldig\'i'),
        backButton: true,
        searchController: _searchController,
        onChanged: (v) => context
            .read<ProductsStockBloc>()
            .add(ProductsStockSearchChanged(v)),
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
                  return StockVariantCard(variant: state.variants[index]);
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
