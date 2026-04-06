import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/product_type_entity.dart';
import '../../domain/usecases/create_product_usecase.dart';
import '../../domain/usecases/get_product_types_usecase.dart';
import 'product_form_event.dart';
import 'product_form_state.dart';

class ProductFormBloc extends Bloc<ProductFormEvent, ProductFormState> {
  final CreateProductUseCase createProductUseCase;
  final GetProductTypesUseCase getProductTypesUseCase;

  ProductFormBloc({
    required this.createProductUseCase,
    required this.getProductTypesUseCase,
  }) : super(const ProductFormInitial()) {
    on<ProductFormStarted>(_onStarted);
    on<ProductFormSubmitted>(_onSubmitted);
  }

  Future<void> _onStarted(
    ProductFormStarted event,
    Emitter<ProductFormState> emit,
  ) async {
    emit(const ProductFormTypesLoading());

    final result = await getProductTypesUseCase();

    result.fold(
      (failure) => emit(const ProductFormReady([])),
      (types) => emit(ProductFormReady(types)),
    );
  }

  Future<void> _onSubmitted(
    ProductFormSubmitted event,
    Emitter<ProductFormState> emit,
  ) async {
    final currentTypes = _currentTypes();
    final densityVal = int.tryParse(event.density);

    if (densityVal == null) {
      emit(ProductFormFailure(
        'Zichlik musbat son bo\'lishi kerak.',
        productTypes: currentTypes,
      ));
      return;
    }

    emit(ProductFormSubmitting(currentTypes));

    final result = await createProductUseCase(
      name: event.name,
      productTypeId: event.productTypeId,
      quality: event.quality,
      density: densityVal,
      color: event.color,
      edge: event.edge,
      unit: event.unit,
      status: event.status,
      imagePath: event.imagePath,
    );

    result.fold(
      (failure) => emit(ProductFormFailure(failure.message, productTypes: currentTypes)),
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
}
