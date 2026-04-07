import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/color_entity.dart';
import '../../domain/usecases/create_product_color_usecase.dart';
import '../../domain/usecases/get_colors_usecase.dart';
import 'product_color_form_event.dart';
import 'product_color_form_state.dart';

class ProductColorFormBloc
    extends Bloc<ProductColorFormEvent, ProductColorFormState> {
  final GetColorsUseCase getColorsUseCase;
  final CreateProductColorUseCase createProductColorUseCase;

  ProductColorFormBloc({
    required this.getColorsUseCase,
    required this.createProductColorUseCase,
  }) : super(const ProductColorFormInitial()) {
    on<ProductColorFormStarted>(_onStarted);
    on<ProductColorFormSubmitted>(_onSubmitted);
  }

  Future<void> _onStarted(
    ProductColorFormStarted event,
    Emitter<ProductColorFormState> emit,
  ) async {
    emit(const ProductColorFormLoading());
    final result = await getColorsUseCase();
    result.fold(
      (failure) => emit(const ProductColorFormReady([])),
      (colors) => emit(ProductColorFormReady(colors)),
    );
  }

  Future<void> _onSubmitted(
    ProductColorFormSubmitted event,
    Emitter<ProductColorFormState> emit,
  ) async {
    final colors = _currentColors();
    emit(ProductColorFormSubmitting(colors));

    final result = await createProductColorUseCase(
      productId: event.productId,
      colorId: event.colorId,
      imagePath: event.imagePath,
    );

    result.fold(
      (failure) => emit(
        ProductColorFormFailure(failure.message, colors: colors),
      ),
      (productColor) => emit(ProductColorFormSuccess(productColor)),
    );
  }

  List<ColorEntity> _currentColors() {
    final s = state;
    if (s is ProductColorFormReady) return s.colors;
    if (s is ProductColorFormSubmitting) return s.colors;
    if (s is ProductColorFormFailure) return s.colors;
    return const [];
  }
}
