import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_products_usecase.dart';
import 'products_event.dart';
import 'products_state.dart';

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final GetProductsUseCase getProductsUseCase;

  String _searchQuery = '';
  Timer? _debounce;

  ProductsBloc({required this.getProductsUseCase}) : super(const ProductsInitial()) {
    on<ProductsLoadRequested>(_onLoadRequested);
    on<ProductsSearchChanged>(_onSearchChanged);
    on<ProductsNextPageRequested>(_onNextPageRequested);
    on<ProductsRefreshRequested>(_onRefreshRequested);
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
        ));
      },
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
