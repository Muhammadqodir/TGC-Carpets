import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/dialogs/confirm_dialog.dart';
import 'package:tgc_client/core/ui/widgets/desktop_status_bar.dart';
import 'package:tgc_client/features/products/domain/entities/product_quality_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_type_entity.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_state.dart';
import 'package:tgc_client/features/products/presentation/bloc/products_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/products_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/products_state.dart';
import 'package:tgc_client/features/products/presentation/widgets/add_product_modal.dart';
import 'package:tgc_client/features/products/presentation/widgets/add_product_color_modal.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_filter_bar.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_table.dart';

/// Full desktop view: top filter bar + scrollable data table.
/// Wraps itself with [ProductFormBloc] to source type/quality filter options.
class ProductsDesktopPage extends StatelessWidget {
  const ProductsDesktopPage({super.key});

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
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  int? _selectedTypeId;
  int? _selectedQualityId;
  String? _selectedStatus;

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

  void _applyFilters({
    int? typeId,
    int? qualityId,
    String? status,
  }) {
    setState(() {
      _selectedTypeId = typeId;
      _selectedQualityId = qualityId;
      _selectedStatus = status;
    });
    context.read<ProductsBloc>().add(
          ProductsFilterChanged(
            productTypeId: typeId,
            productQualityId: qualityId,
            status: status,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductsBloc, ProductsState>(
      listenWhen: (prev, curr) =>
          curr is ProductsLoaded &&
          prev is ProductsLoaded &&
          curr.actionStatus != prev.actionStatus,
      listener: _onActionStatus,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Mahsulotlar'),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
          actions: [
            IconButton(
              onPressed: () => AddProductModal.show(
                context,
                onProductAdded: () => context
                    .read<ProductsBloc>()
                    .add(const ProductsRefreshRequested()),
              ),
              icon: Icon(Icons.add),
            ),
            SizedBox(width: 12),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- Filter bar (uses ProductFormBloc for options) ----
            BlocBuilder<ProductFormBloc, ProductFormState>(
              builder: (context, formState) {
                final types = _typesFromFormState(formState);
                final qualities = _qualitiesFromFormState(formState);
                return ProductFilterBar(
                  searchController: _searchController,
                  onSearchChanged: (v) {
                    context.read<ProductsBloc>().add(ProductsSearchChanged(v));
                  },
                  productTypes: types,
                  productQualities: qualities,
                  selectedTypeId: _selectedTypeId,
                  selectedQualityId: _selectedQualityId,
                  selectedStatus: _selectedStatus,
                  onTypeChanged: (v) => _applyFilters(
                    typeId: v,
                    qualityId: _selectedQualityId,
                    status: _selectedStatus,
                  ),
                  onQualityChanged: (v) => _applyFilters(
                    typeId: _selectedTypeId,
                    qualityId: v,
                    status: _selectedStatus,
                  ),
                  onStatusChanged: (v) => _applyFilters(
                    typeId: _selectedTypeId,
                    qualityId: _selectedQualityId,
                    status: v,
                  ),
                  onRefresh: () => context
                      .read<ProductsBloc>()
                      .add(const ProductsRefreshRequested()),
                );
              },
            ),
            const Divider(height: 1, color: AppColors.divider),

            // ---- Table / states ----
            Expanded(
              child: BlocBuilder<ProductsBloc, ProductsState>(
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
                      return _EmptyState(
                        onAddProduct: () => AddProductModal.show(
                          context,
                          onProductAdded: () => context
                              .read<ProductsBloc>()
                              .add(const ProductsRefreshRequested()),
                        ),
                      );
                    }

                    return ProductDataTable(
                      products: state.products,
                      isLoadingMore: state.isLoadingMore,
                      scrollController: _scrollController,
                      pendingProductId:
                          state.actionStatus is ProductActionPending
                              ? (state.actionStatus as ProductActionPending)
                                  .productId
                              : null,
                      onEdit: (p) => AddProductModal.show(
                        context,
                        product: p,
                        onProductAdded: () => context
                            .read<ProductsBloc>()
                            .add(const ProductsRefreshRequested()),
                      ),
                      onArchiveToggle: (p) => context
                          .read<ProductsBloc>()
                          .add(ProductArchiveToggleRequested(p)),
                      onDelete: (p) async {
                        final confirmed = await ConfirmDialog.show(
                          context: context,
                          title: 'O\'chirishni tasdiqlang',
                          content:
                              '"${p.name}" o\'chirilsinmi? Bu amalni ortga qaytarib bo\'lmaydi.',
                        );
                        if (confirmed && context.mounted) {
                          context
                              .read<ProductsBloc>()
                              .add(ProductDeleteRequested(p.id));
                        }
                      },
                      onAddColor: (p) => AddProductColorModal.show(
                        context,
                        product: p,
                        onColorAdded: () => context
                            .read<ProductsBloc>()
                            .add(const ProductsRefreshRequested()),
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            BlocBuilder<ProductsBloc, ProductsState>(builder: (context, state) {
              final loaded =
                  state is ProductsLoaded ? state.products.length : null;
              final total = state is ProductsLoaded ? state.total : null;
              return DesktopStatusBar(
                child: Text(
                  loaded != null && total != null
                      ? '$loaded / $total ta mahsulot ko\'rsatilmoqda'
                      : '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _onActionStatus(BuildContext context, ProductsState state) {
    if (state is! ProductsLoaded) return;
    final status = state.actionStatus;
    final messenger = ScaffoldMessenger.of(context);
    switch (status) {
      case ProductActionPending():
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Yuklanmoqda...'),
                ],
              ),
              duration: const Duration(seconds: 30),
            ),
          );
      case ProductActionSuccess(message: final msg):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
      case ProductActionFailure(message: final msg):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
      case ProductActionIdle():
        break;
    }
  }

  List<ProductTypeEntity> _typesFromFormState(ProductFormState s) =>
      switch (s) {
        ProductFormReady r => r.productTypes,
        ProductFormSubmitting r => r.productTypes,
        ProductFormFailure r => r.productTypes,
        _ => const [],
      };

  List<ProductQualityEntity> _qualitiesFromFormState(ProductFormState s) =>
      switch (s) {
        ProductFormReady r => r.productQualities,
        ProductFormSubmitting r => r.productQualities,
        ProductFormFailure r => r.productQualities,
        _ => const [],
      };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddProduct});

  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Mahsulotlar topilmadi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yangi mahsulot qo\'shing yoki filtrlarni o\'zgartiring.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAddProduct,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Mahsulot qo\'shish'),
          ),
        ],
      ),
    );
  }
}
