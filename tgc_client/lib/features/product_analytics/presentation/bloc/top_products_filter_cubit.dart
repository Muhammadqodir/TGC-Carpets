import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/product_analytics_entity.dart';
import '../../domain/usecases/get_top_products_usecase.dart';
import 'top_products_filter_state.dart';

class TopProductsFilterCubit extends Cubit<TopProductsFilterState> {
  final GetTopProductsUseCase _useCase;

  String _periodFrom;
  String _periodTo;
  int? _typeId;
  int? _qualityId;
  int? _colorId;
  int? _sizeId;
  int? _edgeId;
  int _limit = 10;

  TopProductsFilterCubit({
    required GetTopProductsUseCase useCase,
    required String periodFrom,
    required String periodTo,
  })  : _useCase = useCase,
        _periodFrom = periodFrom,
        _periodTo = periodTo,
        super(const TopProductsFilterInitial()) {
    load();
  }

  void updatePeriod(String from, String to) {
    _periodFrom = from;
    _periodTo   = to;
    load();
  }

  void setTypeId(int? id) {
    _typeId = id;
    load();
  }

  void setQualityId(int? id) {
    _qualityId = id;
    load();
  }

  void setColorId(int? id) {
    _colorId = id;
    load();
  }

  void setSizeId(int? id) {
    _sizeId = id;
    load();
  }

  void setEdgeId(int? id) {
    _edgeId = id;
    load();
  }

  void setLimit(int limit) {
    _limit = limit;
    load();
  }

  Future<void> load() async {
    final prev = _currentProducts();
    emit(TopProductsFilterLoading(
      previous:  prev,
      typeId:    _typeId,
      qualityId: _qualityId,
      colorId:   _colorId,
      sizeId:    _sizeId,
      edgeId:    _edgeId,
      limit:     _limit,
    ));

    final result = await _useCase(GetTopProductsParams(
      periodFrom: _periodFrom,
      periodTo:   _periodTo,
      typeId:     _typeId,
      qualityId:  _qualityId,
      colorId:    _colorId,
      sizeId:     _sizeId,
      edgeId:     _edgeId,
      limit:      _limit,
    ));

    result.fold(
      (failure) => emit(TopProductsFilterError(
        message:   failure.message,
        typeId:    _typeId,
        qualityId: _qualityId,
        colorId:   _colorId,
        sizeId:    _sizeId,
        edgeId:    _edgeId,
        limit:     _limit,
      )),
      (products) => emit(TopProductsFilterLoaded(
        products:  products,
        typeId:    _typeId,
        qualityId: _qualityId,
        colorId:   _colorId,
        sizeId:    _sizeId,
        edgeId:    _edgeId,
        limit:     _limit,
      )),
    );
  }

  List<TopProductItem> _currentProducts() {
    final s = state;
    if (s is TopProductsFilterLoaded) return s.products;
    if (s is TopProductsFilterLoading) return s.previousProducts;
    return const [];
  }

  bool get hasActiveFilters =>
      _typeId != null ||
      _qualityId != null ||
      _colorId != null ||
      _sizeId != null ||
      _edgeId != null;

  void clearFilters() {
    _typeId    = null;
    _qualityId = null;
    _colorId   = null;
    _sizeId    = null;
    _edgeId    = null;
    load();
  }
}
