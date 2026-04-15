import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/appbar_search.dart';
import 'package:tgc_client/features/products/domain/entities/product_quality_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_size_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_type_entity.dart';
import 'package:tgc_client/features/products/domain/usecases/get_product_sizes_usecase.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_state.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_bloc.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_event.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_state.dart';
import 'package:tgc_client/features/products_stock/presentation/widgets/stock_variant_card.dart';

/// Mobile list view for the Products Stock feature.
class ProductsStockMobilePage extends StatelessWidget {
  const ProductsStockMobilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductFormBloc>()..add(const ProductFormStarted()),
      child: const _MobileBody(),
    );
  }
}

// ---------------------------------------------------------------------------

class _MobileBody extends StatefulWidget {
  const _MobileBody();

  @override
  State<_MobileBody> createState() => _MobileBodyState();
}

class _MobileBodyState extends State<_MobileBody> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _getSizes = sl<GetProductSizesUseCase>();

  int? _selectedTypeId;
  int? _selectedQualityId;
  int? _selectedSizeId;
  List<ProductSizeEntity> _sizes = [];

  bool get _hasActiveFilters =>
      _selectedTypeId != null ||
      _selectedQualityId != null ||
      _selectedSizeId != null;

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

  void _applyFilters({
    required int? typeId,
    required int? qualityId,
    required int? sizeId,
    required List<ProductSizeEntity> sizes,
  }) {
    setState(() {
      _selectedTypeId = typeId;
      _selectedQualityId = qualityId;
      _selectedSizeId = sizeId;
      _sizes = sizes;
    });
    context.read<ProductsStockBloc>().add(
          ProductsStockFilterChanged(
            productTypeId: typeId,
            productQualityId: qualityId,
            productSizeId: sizeId,
          ),
        );
  }

  Future<void> _openFilterSheet(
    List<ProductTypeEntity> types,
    List<ProductQualityEntity> qualities,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FilterBottomSheet(
        types: types,
        qualities: qualities,
        getSizes: _getSizes,
        initialTypeId: _selectedTypeId,
        initialQualityId: _selectedQualityId,
        initialSizeId: _selectedSizeId,
        initialSizes: _sizes,
        onApply: _applyFilters,
      ),
    );
  }

  List<ProductTypeEntity> _typesFrom(ProductFormState s) {
    if (s is ProductFormReady) return s.productTypes;
    if (s is ProductFormSubmitting) return s.productTypes;
    if (s is ProductFormFailure) return s.productTypes;
    return const [];
  }

  List<ProductQualityEntity> _qualitiesFrom(ProductFormState s) {
    if (s is ProductFormReady) return s.productQualities;
    if (s is ProductFormSubmitting) return s.productQualities;
    if (s is ProductFormFailure) return s.productQualities;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductFormBloc, ProductFormState>(
      builder: (context, formState) {
        final types = _typesFrom(formState);
        final qualities = _qualitiesFrom(formState);

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
                tooltip: 'Filter',
                icon: Badge(
                  isLabelVisible: _hasActiveFilters,
                  child: const Icon(Icons.filter_list_outlined),
                ),
                onPressed: () => _openFilterSheet(types, qualities),
              ),
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
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bottom sheet
// ---------------------------------------------------------------------------

class _FilterBottomSheet extends StatefulWidget {
  const _FilterBottomSheet({
    required this.types,
    required this.qualities,
    required this.getSizes,
    required this.initialTypeId,
    required this.initialQualityId,
    required this.initialSizeId,
    required this.initialSizes,
    required this.onApply,
  });

  final List<ProductTypeEntity> types;
  final List<ProductQualityEntity> qualities;
  final GetProductSizesUseCase getSizes;
  final int? initialTypeId;
  final int? initialQualityId;
  final int? initialSizeId;
  final List<ProductSizeEntity> initialSizes;
  final void Function({
    required int? typeId,
    required int? qualityId,
    required int? sizeId,
    required List<ProductSizeEntity> sizes,
  }) onApply;

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late int? _typeId;
  late int? _qualityId;
  late int? _sizeId;
  late List<ProductSizeEntity> _sizes;
  bool _loadingSizes = false;

  @override
  void initState() {
    super.initState();
    _typeId = widget.initialTypeId;
    _qualityId = widget.initialQualityId;
    _sizeId = widget.initialSizeId;
    _sizes = List.of(widget.initialSizes);
  }

  Future<void> _onTypeChanged(int? typeId) async {
    setState(() {
      _typeId = typeId;
      _sizeId = null;
      _sizes = [];
    });
    if (typeId == null) return;
    setState(() => _loadingSizes = true);
    final result = await widget.getSizes(productTypeId: typeId);
    if (!mounted) return;
    result.fold(
      (_) => setState(() => _loadingSizes = false),
      (sizes) => setState(() {
        _sizes = sizes;
        _loadingSizes = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Filter', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _typeId = null;
                    _qualityId = null;
                    _sizeId = null;
                    _sizes = [];
                  });
                },
                child: const Text('Tozalash'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Type
          DropdownButtonFormField<int>(
            value: _typeId,
            decoration: const InputDecoration(
              labelText: 'Turi',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Barchasi')),
              ...widget.types.map(
                (t) => DropdownMenuItem(value: t.id, child: Text(t.type)),
              ),
            ],
            onChanged: _onTypeChanged,
          ),
          const SizedBox(height: 12),
          // Quality
          DropdownButtonFormField<int>(
            value: _qualityId,
            decoration: const InputDecoration(
              labelText: 'Sifat',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Barchasi')),
              ...widget.qualities.map(
                (q) => DropdownMenuItem(
                  value: q.id,
                  child: Text(
                    q.density != null
                        ? '${q.qualityName} (${q.density})'
                        : q.qualityName,
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _qualityId = v),
          ),
          const SizedBox(height: 12),
          // Size — only shown when a type is selected
          if (_typeId != null) ...[
            _loadingSizes
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : DropdownButtonFormField<int>(
                    value: _sizeId,
                    decoration: const InputDecoration(
                      labelText: 'O\'lcham',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Barchasi')),
                      ..._sizes.map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.dimensions),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _sizeId = v),
                  ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: () {
              widget.onApply(
                typeId: _typeId,
                qualityId: _qualityId,
                sizeId: _sizeId,
                sizes: _sizes,
              );
              Navigator.of(context).pop();
            },
            child: const Text('Qo\'llash'),
          ),
        ],
      ),
    );
  }
}
