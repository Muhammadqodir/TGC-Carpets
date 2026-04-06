import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/delete_product_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import '../../domain/usecases/update_product_usecase.dart';
import 'products_event.dart';
import 'products_state.dart';

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final GetProductsUseCase getProductsUseCase;
  final UpdateProductUseCase updateProductUseCase;
  final DeleteProductUseCase deleteProductUseCase;

  String _searchQuery = '';
  int? _filterTypeId;
  int? _filterQualityId;
  String? _filterStatus;
  Timer? _debounce;

  ProductsBloc({
    required this.getProductsUseCase,
    required this.updateProductUseCase,
    required this.deleteProductUseCase,
  }) : super(const ProductsInitial()) {
    on<ProductsLoadRequested>(_onLoadRequested);
    on<ProductsSearchChanged>(_onSearchChanged);
    on<ProductsNextPageRequested>(_onNextPageRequested);
    on<ProductsRefreshRequested>(_onRefreshRequested);
    on<ProductsFilterChanged>(_onFilterChanged);
    on<ProductArchiveToggleRequested>(_onArchiveToggle);
    on<ProductDeleteRequested>(_onDelete);
  }

  Future<void> _onLoadRequested(
    ProductsLoadRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
    ProductsRefreshRequested event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  void _onSearchChanged(
    ProductsSearchChanged event,
    Emitter<ProductsState> emit,
  ) {
    _searchQuery = event.query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      add(const ProductsLoadRequested());
    });
  }

  void _onFilterChanged(
    ProductsFilterChanged event,
    Emitter<ProductsState> emit,
  ) {
    _filterTypeId = event.productTypeId;
    _filterQualityId = event.productQualityId;
    _filterStatus = event.status;
    add(const ProductsLoadRequested());
  }

  Future<void> _onNextPageRequested(
    ProductsNextPageRequested event,
    Emitter<ProductsState> emit,
  ) async {
    final current = state;
    if (current is! ProductsLoaded || !current.hasNextPage || current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  Future<void> _fetchPage(
    Emitter<ProductsState> emit, {
    required int page,
    required bool replace,
  }) async {
    final result = await getProductsUseCase(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      productTypeId: _filterTypeId,
      productQualityId: _filterQualityId,
      status: _filterStatus,
      page: page,
    );

    result.fold(
      (failure) => emit(ProductsError(failure.message)),
      (paginated) {
        final current = state;
        final existing =
            (!replace && current is ProductsLoaded) ? current.products : [];
        emit(ProductsLoaded(
          products: [...existing, ...paginated.data],
          hasNextPage: paginated.hasNextPage,
          currentPage: paginated.currentPage,
          total: paginated.total,
          filterTypeId: _filterTypeId,
          filterQualityId: _filterQualityId,
          filterStatus: _filterStatus,
        ));
      },
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  Future<void> _onArchiveToggle(
    ProductArchiveToggleRequested event,
    Emitter<ProductsState> emit,
  ) async {
    final current = state;
    if (current is! ProductsLoaded) return;

    emit(current.copyWith(actionStatus: ProductActionPending(event.product.id)));

    final newStatus = event.product.isActive ? 'archived' : 'active';
    final result = await updateProductUseCase(
      id: event.product.id,
      status: newStatus,
    );

    result.fold(
      (failure) => emit(current.copyWith(
        actionStatus: ProductActionFailure(failure.message),
      )),
      (_) {
        final newStatus = event.product.isActive ? 'archived' : 'active';
        final updatedProduct = event.product.copyWith(status: newStatus);
        emit(current.copyWith(
          products: current.products
              .map((p) => p.id == updatedProduct.id ? updatedProduct : p)
              .toList(),
          actionStatus: ProductActionSuccess(
            updatedProduct.isActive
                ? '"${updatedProduct.name}" faollashtirildi.'
                : '"${updatedProduct.name}" arxivlandi.',
          ),
        ));
      },
    );
  }

  Future<void> _onDelete(
    ProductDeleteRequested event,
    Emitter<ProductsState> emit,
  ) async {
    final current = state;
    if (current is! ProductsLoaded) return;

    final productIndex =
        current.products.indexWhere((p) => p.id == event.productId);
    if (productIndex == -1) return;
    final product = current.products[productIndex];

    emit(current.copyWith(actionStatus: ProductActionPending(event.productId)));

    final result = await deleteProductUseCase(id: event.productId);

    result.fold(
      (failure) => emit(current.copyWith(
        actionStatus: ProductActionFailure(failure.message),
      )),
      (_) => emit(current.copyWith(
        products: current.products
            .where((p) => p.id != event.productId)
            .toList(),
        total: current.total > 0 ? current.total - 1 : 0,
        actionStatus: ProductActionSuccess('"${product.name}" o\'chirildi.'),
      )),
    );
  }
}
