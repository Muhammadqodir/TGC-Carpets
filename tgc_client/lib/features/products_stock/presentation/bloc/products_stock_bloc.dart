import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/stock_variant_entity.dart';
import '../../domain/usecases/get_stock_variants_usecase.dart';
import 'products_stock_event.dart';
import 'products_stock_state.dart';

class ProductsStockBloc extends Bloc<ProductsStockEvent, ProductsStockState> {
  final GetStockVariantsUseCase getStockVariantsUseCase;

  int? _filterTypeId;
  int? _filterQualityId;
  int? _filterSizeId;

  ProductsStockBloc({required this.getStockVariantsUseCase})
      : super(const ProductsStockInitial()) {
    on<ProductsStockLoadRequested>(_onLoadRequested);
    on<ProductsStockRefreshRequested>(_onRefreshRequested);
    on<ProductsStockNextPageRequested>(_onNextPageRequested);
    on<ProductsStockFilterChanged>(_onFilterChanged);
  }

  Future<void> _onLoadRequested(
    ProductsStockLoadRequested event,
    Emitter<ProductsStockState> emit,
  ) async {
    emit(const ProductsStockLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  Future<void> _onRefreshRequested(
    ProductsStockRefreshRequested event,
    Emitter<ProductsStockState> emit,
  ) async {
    emit(const ProductsStockLoading());
    await _fetchPage(emit, page: 1, replace: true);
  }

  void _onFilterChanged(
    ProductsStockFilterChanged event,
    Emitter<ProductsStockState> emit,
  ) {
    _filterTypeId    = event.productTypeId;
    _filterQualityId = event.productQualityId;
    _filterSizeId    = event.productSizeId;
    add(const ProductsStockLoadRequested());
  }

  Future<void> _onNextPageRequested(
    ProductsStockNextPageRequested event,
    Emitter<ProductsStockState> emit,
  ) async {
    final current = state;
    if (current is! ProductsStockLoaded ||
        !current.hasNextPage ||
        current.isLoadingMore) {
      return;
    }
    emit(current.copyWith(isLoadingMore: true));
    await _fetchPage(emit, page: current.currentPage + 1, replace: false);
  }

  Future<void> _fetchPage(
    Emitter<ProductsStockState> emit, {
    required int page,
    required bool replace,
  }) async {
    final result = await getStockVariantsUseCase(
      productTypeId:    _filterTypeId,
      productQualityId: _filterQualityId,
      productSizeId:    _filterSizeId,
      page:             page,
    );

    result.fold(
      (failure) => emit(ProductsStockError(failure.message)),
      (paginated) {
        final prev =
            (state is ProductsStockLoaded) ? state as ProductsStockLoaded : null;
        final existing =
            replace ? <StockVariantEntity>[] : (prev?.variants ?? []);

        emit(ProductsStockLoaded(
          variants:        [...existing, ...paginated.data],
          hasNextPage:     paginated.hasNextPage,
          isLoadingMore:   false,
          currentPage:     paginated.currentPage,
          total:           paginated.total,
          filterTypeId:    _filterTypeId,
          filterQualityId: _filterQualityId,
          filterSizeId:    _filterSizeId,
        ));
      },
    );
  }
}
