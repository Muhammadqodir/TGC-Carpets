import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/desktop_status_bar.dart';
import 'package:tgc_client/features/products/domain/entities/product_quality_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_type_entity.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_state.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_bloc.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_event.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_state.dart';
import 'package:tgc_client/features/products_stock/presentation/widgets/stock_filter_bar.dart';
import 'package:tgc_client/features/products_stock/presentation/widgets/stock_table.dart';

/// Full-width desktop view: filter bar + scrollable stock table.
class ProductsStockDesktopPage extends StatelessWidget {
  const ProductsStockDesktopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductFormBloc>()..add(const ProductFormStarted()),
      child: const _DesktopView(),
    );
  }
}

// ---------------------------------------------------------------------------

class _DesktopView extends StatefulWidget {
  const _DesktopView();

  @override
  State<_DesktopView> createState() => _DesktopViewState();
}

class _DesktopViewState extends State<_DesktopView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  int? _selectedTypeId;
  int? _selectedQualityId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ProductsStockBloc>().add(const ProductsStockNextPageRequested());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSizes(int? typeId) async {}

  void _applyFilters({
    int? typeId,
    int? qualityId,
  }) {
    setState(() {
      _selectedTypeId = typeId;
      _selectedQualityId = qualityId;
    });
    context.read<ProductsStockBloc>().add(
          ProductsStockFilterChanged(
            productTypeId:    typeId,
            productQualityId: qualityId,
          ),
        );
  }

  List<ProductTypeEntity> _typesFromFormState(ProductFormState s) {
    if (s is ProductFormReady) return s.productTypes;
    if (s is ProductFormSubmitting) return s.productTypes;
    if (s is ProductFormFailure) return s.productTypes;
    return const [];
  }

  List<ProductQualityEntity> _qualitiesFromFormState(ProductFormState s) {
    if (s is ProductFormReady) return s.productQualities;
    if (s is ProductFormSubmitting) return s.productQualities;
    if (s is ProductFormFailure) return s.productQualities;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mahsulotlar qoldig\'i'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Filter bar ──────────────────────────────────────────────────
          BlocBuilder<ProductFormBloc, ProductFormState>(
            builder: (context, formState) {
              return StockFilterBar(
                productTypes:       _typesFromFormState(formState),
                productQualities:   _qualitiesFromFormState(formState),
                selectedTypeId:     _selectedTypeId,
                selectedQualityId:  _selectedQualityId,
                searchController:   _searchController,
                onSearchChanged:    (v) => context
                    .read<ProductsStockBloc>()
                    .add(ProductsStockSearchChanged(v)),
                onTypeChanged: (id) {
                  _applyFilters(
                    typeId:     id,
                    qualityId:  _selectedQualityId,
                  );
                  _loadSizes(id);
                },
                onQualityChanged: (id) => _applyFilters(
                  typeId:    _selectedTypeId,
                  qualityId: id,
                ),
                onRefresh: () => context
                    .read<ProductsStockBloc>()
                    .add(const ProductsStockRefreshRequested()),
              );
            },
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ── Table / states ──────────────────────────────────────────────
          Expanded(
            child: BlocBuilder<ProductsStockBloc, ProductsStockState>(
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

                  return StockVariantDataTable(
                    variants:         state.variants,
                    isLoadingMore:    state.isLoadingMore,
                    scrollController: _scrollController,
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Status bar ──────────────────────────────────────────────────
          BlocBuilder<ProductsStockBloc, ProductsStockState>(
            builder: (context, state) {
              final loaded =
                  state is ProductsStockLoaded ? state.variants.length : null;
              final total =
                  state is ProductsStockLoaded ? state.total : null;
              return DesktopStatusBar(
                child: Text(
                  loaded != null && total != null
                      ? '$loaded / $total ta variant ko\'rsatilmoqda'
                      : '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
