import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/product_quality_entity.dart';
import '../../domain/entities/product_type_entity.dart';
import '../../domain/usecases/create_product_usecase.dart';
import '../../domain/usecases/get_product_qualities_usecase.dart';
import '../../domain/usecases/get_product_types_usecase.dart';
import '../../domain/usecases/update_product_usecase.dart';
import 'product_form_event.dart';
import 'product_form_state.dart';

class ProductFormBloc extends Bloc<ProductFormEvent, ProductFormState> {
  final CreateProductUseCase createProductUseCase;
  final UpdateProductUseCase updateProductUseCase;
  final GetProductTypesUseCase getProductTypesUseCase;
  final GetProductQualitiesUseCase getProductQualitiesUseCase;

  ProductFormBloc({
    required this.createProductUseCase,
    required this.updateProductUseCase,
    required this.getProductTypesUseCase,
    required this.getProductQualitiesUseCase,
  }) : super(const ProductFormInitial()) {
    on<ProductFormStarted>(_onStarted);
    on<ProductFormSubmitted>(_onSubmitted);
    on<ProductFormUpdateSubmitted>(_onUpdateSubmitted);
  }

  Future<void> _onStarted(
    ProductFormStarted event,
    Emitter<ProductFormState> emit,
  ) async {
    emit(const ProductFormTypesLoading());

    final results = await Future.wait([
      getProductTypesUseCase(),
      getProductQualitiesUseCase(),
    ]);

    final types = results[0].fold((_) => <ProductTypeEntity>[], (v) => v as List<ProductTypeEntity>);
    final qualities = results[1].fold((_) => <ProductQualityEntity>[], (v) => v as List<ProductQualityEntity>);

    emit(ProductFormReady(types, productQualities: qualities));
  }

  Future<void> _onSubmitted(
    ProductFormSubmitted event,
    Emitter<ProductFormState> emit,
  ) async {
    final currentTypes = _currentTypes();
    final currentQualities = _currentQualities();

    emit(ProductFormSubmitting(currentTypes, productQualities: currentQualities));

    final result = await createProductUseCase(
      name: event.name,
      productTypeId: event.productTypeId,
      productQualityId: event.productQualityId,
      color: event.color,
      unit: event.unit,
      status: event.status,
      imagePath: event.imagePath,
    );

    result.fold(
      (failure) => emit(ProductFormFailure(
        failure.message,
        productTypes: currentTypes,
        productQualities: currentQualities,
      )),
      (product) => emit(ProductFormSuccess(product)),
    );
  }

  List<ProductTypeEntity> _currentTypes() {
    final s = state;
    if (s is ProductFormReady) return s.productTypes;
    if (s is ProductFormSubmitting) return s.productTypes;
    if (s is ProductFormFailure) return s.productTypes;
    return const [];
  }

  List<ProductQualityEntity> _currentQualities() {
    final s = state;
    if (s is ProductFormReady) return s.productQualities;
    if (s is ProductFormSubmitting) return s.productQualities;
    if (s is ProductFormFailure) return s.productQualities;
    return const [];
  }

  Future<void> _onUpdateSubmitted(
    ProductFormUpdateSubmitted event,
    Emitter<ProductFormState> emit,
  ) async {
    final currentTypes = _currentTypes();
    final currentQualities = _currentQualities();
    emit(ProductFormSubmitting(currentTypes, productQualities: currentQualities));

    final result = await updateProductUseCase(
      id: event.productId,
      name: event.name,
      productTypeId: event.productTypeId,
      productQualityId: event.productQualityId,
      color: event.color,
      unit: event.unit,
      status: event.status,
      imagePath: event.imagePath,
    );

    result.fold(
      (failure) => emit(ProductFormFailure(
        failure.message,
        productTypes: currentTypes,
        productQualities: currentQualities,
      )),
      (product) => emit(ProductFormSuccess(product)),
    );
  }
}
