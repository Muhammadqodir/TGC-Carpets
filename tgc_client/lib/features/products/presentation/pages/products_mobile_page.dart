import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/ui/widgets/appbar_search.dart';
import 'package:tgc_client/features/products/presentation/bloc/products_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/products_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/products_state.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_item.dart';

/// Mobile list view for the products feature.
class ProductsMobilePage extends StatefulWidget {
  const ProductsMobilePage({super.key});

  @override
  State<ProductsMobilePage> createState() => _ProductsMobilePageState();
}

class _ProductsMobilePageState extends State<ProductsMobilePage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ProductsBloc>().add(const ProductsNextPageRequested());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarSearch(
        title: const Text('Mahsulotlar'),
        searchController: _searchController,
        onChanged: (value) =>
            context.read<ProductsBloc>().add(ProductsSearchChanged(value)),
        backButton: true,
        actions: [
          IconButton(
            onPressed: () => context.pushNamed(AppRoutes.addProductName),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
      body: BlocBuilder<ProductsBloc, ProductsState>(
        builder: (context, state) {
          if (state is ProductsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ProductsError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context
                        .read<ProductsBloc>()
                        .add(const ProductsRefreshRequested()),
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          if (state is ProductsLoaded) {
            if (state.products.isEmpty) {
              return const Center(child: Text('Mahsulotlar topilmadi.'));
            }

            return RefreshIndicator(
              onRefresh: () async => context
                  .read<ProductsBloc>()
                  .add(const ProductsRefreshRequested()),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount:
                    state.products.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  if (index >= state.products.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return ProductItem(product: state.products[index]);
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
