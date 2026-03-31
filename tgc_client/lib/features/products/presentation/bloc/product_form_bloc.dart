import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/create_product_usecase.dart';
import 'product_form_event.dart';
import 'product_form_state.dart';

class ProductFormBloc extends Bloc<ProductFormEvent, ProductFormState> {
  final CreateProductUseCase createProductUseCase;

  ProductFormBloc({required this.createProductUseCase})
      : super(const ProductFormInitial()) {
    on<ProductFormSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    ProductFormSubmitted event,
    Emitter<ProductFormState> emit,
  ) async {
    emit(const ProductFormSubmitting());

    final lengthVal = int.tryParse(event.length);
    final widthVal = int.tryParse(event.width);
    final densityVal = int.tryParse(event.density);

    if (lengthVal == null || widthVal == null || densityVal == null) {
      emit(const ProductFormFailure('Length, width, and density must be valid numbers.'));
      return;
    }

    final result = await createProductUseCase(
      name: event.name,
      length: lengthVal,
      width: widthVal,
      quality: event.quality,
      density: densityVal,
      color: event.color,
      edge: event.edge,
      unit: event.unit,
      status: event.status,
      imagePath: event.imagePath,
    );

    result.fold(
      (failure) => emit(ProductFormFailure(failure.message)),
      (product) => emit(ProductFormSuccess(product)),
    );
  }
}
