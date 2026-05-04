import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/color_usecases.dart';
import '../../domain/usecases/load_product_attributes_usecase.dart';
import '../../domain/usecases/product_quality_usecases.dart';
import '../../domain/usecases/product_size_usecases.dart';
import '../../domain/usecases/product_type_usecases.dart';
import '../../../orders/presentation/widgets/order_product_size_multi_picker_sheet.dart';
import '../../../products/presentation/widgets/product_size_picker_sheet.dart';
import 'product_attributes_event.dart';
import 'product_attributes_state.dart';

class ProductAttributesBloc extends Bloc<ProductAttributesEvent, ProductAttributesState> {
  final LoadProductAttributesUseCase loadUseCase;
  final CreateColorUseCase createColorUseCase;
  final UpdateColorUseCase updateColorUseCase;
  final DeleteColorUseCase deleteColorUseCase;
  final CreateProductTypeUseCase createProductTypeUseCase;
  final UpdateProductTypeUseCase updateProductTypeUseCase;
  final DeleteProductTypeUseCase deleteProductTypeUseCase;
  final CreateProductQualityUseCase createProductQualityUseCase;
  final UpdateProductQualityUseCase updateProductQualityUseCase;
  final DeleteProductQualityUseCase deleteProductQualityUseCase;
  final CreateProductSizeUseCase createProductSizeUseCase;
  final UpdateProductSizeUseCase updateProductSizeUseCase;
  final DeleteProductSizeUseCase deleteProductSizeUseCase;

  ProductAttributesBloc({
    required this.loadUseCase,
    required this.createColorUseCase,
    required this.updateColorUseCase,
    required this.deleteColorUseCase,
    required this.createProductTypeUseCase,
    required this.updateProductTypeUseCase,
    required this.deleteProductTypeUseCase,
    required this.createProductQualityUseCase,
    required this.updateProductQualityUseCase,
    required this.deleteProductQualityUseCase,
    required this.createProductSizeUseCase,
    required this.updateProductSizeUseCase,
    required this.deleteProductSizeUseCase,
  }) : super(const ProductAttributesInitial()) {
    on<ProductAttributesLoadRequested>(_onLoad);
    on<ProductAttributesRefreshRequested>(_onLoad);

    on<ColorCreateRequested>(_onColorCreate);
    on<ColorUpdateRequested>(_onColorUpdate);
    on<ColorDeleteRequested>(_onColorDelete);

    on<ProductTypeCreateRequested>(_onTypeCreate);
    on<ProductTypeUpdateRequested>(_onTypeUpdate);
    on<ProductTypeDeleteRequested>(_onTypeDelete);

    on<ProductQualityCreateRequested>(_onQualityCreate);
    on<ProductQualityUpdateRequested>(_onQualityUpdate);
    on<ProductQualityDeleteRequested>(_onQualityDelete);

    on<ProductSizeCreateRequested>(_onSizeCreate);
    on<ProductSizeUpdateRequested>(_onSizeUpdate);
    on<ProductSizeDeleteRequested>(_onSizeDelete);
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> _onLoad(
    ProductAttributesEvent event,
    Emitter<ProductAttributesState> emit,
  ) async {
    emit(const ProductAttributesLoading());
    final (colors, types, qualities, sizes) = await loadUseCase();

    final colorsData = colors.fold((f) => null, (v) => v);
    final typesData = types.fold((f) => null, (v) => v);
    final qualitiesData = qualities.fold((f) => null, (v) => v);
    final sizesData = sizes.fold((f) => null, (v) => v);

    final error = colors.fold((f) => f.message, (_) => null) ??
        types.fold((f) => f.message, (_) => null) ??
        qualities.fold((f) => f.message, (_) => null) ??
        sizes.fold((f) => f.message, (_) => null);

    if (error != null) {
      emit(ProductAttributesError(error));
      return;
    }

    emit(ProductAttributesLoaded(
      colors: colorsData!,
      productTypes: typesData!,
      productQualities: qualitiesData!,
      productSizes: sizesData!,
    ));
  }

  // ── Colors ──────────────────────────────────────────────────────────────────

  Future<void> _onColorCreate(
    ColorCreateRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await createColorUseCase(name: event.name);
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (color) => emit(current.copyWith(
        colors: [...current.colors, color]..sort((a, b) => a.name.compareTo(b.name)),
        actionStatus: AttributeActionSuccess('"${color.name}" rangi qo\'shildi.'),
      )),
    );
  }

  Future<void> _onColorUpdate(
    ColorUpdateRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await updateColorUseCase(id: event.id, name: event.name);
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (color) {
        final updated = current.colors.map((c) => c.id == color.id ? color : c).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        emit(current.copyWith(
          colors: updated,
          actionStatus: AttributeActionSuccess('"${color.name}" yangilandi.'),
        ));
      },
    );
  }

  Future<void> _onColorDelete(
    ColorDeleteRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await deleteColorUseCase(id: event.id, replaceWithId: event.replaceWithId);
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (_) => emit(current.copyWith(
        colors: current.colors.where((c) => c.id != event.id).toList(),
        actionStatus: const AttributeActionSuccess('Rang o\'chirildi.'),
      )),
    );
  }

  Future<void> _onTypeCreate(
    ProductTypeCreateRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await createProductTypeUseCase(type: event.type);
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (pt) => emit(current.copyWith(
        productTypes: [...current.productTypes, pt]..sort((a, b) => a.type.compareTo(b.type)),
        actionStatus: AttributeActionSuccess('"${pt.type}" turi qo\'shildi.'),
      )),
    );
  }

  Future<void> _onTypeUpdate(
    ProductTypeUpdateRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await updateProductTypeUseCase(id: event.id, type: event.type);
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (pt) {
        final updated = current.productTypes.map((t) => t.id == pt.id ? pt : t).toList()
          ..sort((a, b) => a.type.compareTo(b.type));
        emit(current.copyWith(
          productTypes: updated,
          actionStatus: AttributeActionSuccess('"${pt.type}" yangilandi.'),
        ));
      },
    );
  }

  Future<void> _onTypeDelete(
    ProductTypeDeleteRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await deleteProductTypeUseCase(id: event.id, replaceWithId: event.replaceWithId);
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (_) => emit(current.copyWith(
        productTypes: current.productTypes.where((t) => t.id != event.id).toList(),
        productSizes: current.productSizes.where((s) => s.productTypeId != event.id).toList(),
        actionStatus: const AttributeActionSuccess('Tur o\'chirildi.'),
      )),
    );
  }
  Future<void> _onQualityCreate(
    ProductQualityCreateRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await createProductQualityUseCase(qualityName: event.qualityName, density: event.density);
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (q) => emit(current.copyWith(
        productQualities: [...current.productQualities, q]
          ..sort((a, b) => a.qualityName.compareTo(b.qualityName)),
        actionStatus: AttributeActionSuccess('"${q.qualityName}" sifati qo\'shildi.'),
      )),
    );
  }

  Future<void> _onQualityUpdate(
    ProductQualityUpdateRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await updateProductQualityUseCase(id: event.id, qualityName: event.qualityName, density: event.density);
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (q) {
        final updated = current.productQualities.map((e) => e.id == q.id ? q : e).toList()
          ..sort((a, b) => a.qualityName.compareTo(b.qualityName));
        emit(current.copyWith(
          productQualities: updated,
          actionStatus: AttributeActionSuccess('"${q.qualityName}" yangilandi.'),
        ));
      },
    );
  }

  Future<void> _onQualityDelete(
    ProductQualityDeleteRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await deleteProductQualityUseCase(id: event.id, replaceWithId: event.replaceWithId);
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (_) => emit(current.copyWith(
        productQualities: current.productQualities.where((q) => q.id != event.id).toList(),
        actionStatus: const AttributeActionSuccess('Sifat o\'chirildi.'),
      )),
    );
  }

  Future<void> _onSizeCreate(
    ProductSizeCreateRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await createProductSizeUseCase(
      length: event.length,
      width: event.width,
      productTypeId: event.productTypeId,
    );
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (s) {
        // Clear size picker caches
        OrderProductSizeMultiPickerSheet.clearCache();
        ProductSizePickerSheet.clearCache();
        emit(current.copyWith(
          productSizes: [...current.productSizes, s]
            ..sort((a, b) {
              final cmp = a.length.compareTo(b.length);
              return cmp != 0 ? cmp : a.width.compareTo(b.width);
            }),
          actionStatus: AttributeActionSuccess('"${s.dimensions}" o\'lcham qo\'shildi.'),
        ));
      },
    );
  }

  Future<void> _onSizeUpdate(
    ProductSizeUpdateRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await updateProductSizeUseCase(
      id: event.id,
      length: event.length,
      width: event.width,
      productTypeId: event.productTypeId,
    );
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (s) {
        // Clear size picker caches
        OrderProductSizeMultiPickerSheet.clearCache();
        ProductSizePickerSheet.clearCache();
        final updated = current.productSizes.map((e) => e.id == s.id ? s : e).toList()
          ..sort((a, b) {
            final cmp = a.length.compareTo(b.length);
            return cmp != 0 ? cmp : a.width.compareTo(b.width);
          });
        emit(current.copyWith(
          productSizes: updated,
          actionStatus: AttributeActionSuccess('"${s.dimensions}" yangilandi.'),
        ));
      },
    );
  }

  Future<void> _onSizeDelete(
    ProductSizeDeleteRequested event,
    Emitter<ProductAttributesState> emit,
  ) async {
    final current = _requireLoaded(emit);
    if (current == null) return;
    emit(current.copyWith(actionStatus: const AttributeActionPending()));
    final result = await deleteProductSizeUseCase(id: event.id, replaceWithId: event.replaceWithId);
    result.fold(
      (f) => emit(current.copyWith(actionStatus: AttributeActionFailure(f.message))),
      (_) {
        // Clear size picker caches
        OrderProductSizeMultiPickerSheet.clearCache();
        ProductSizePickerSheet.clearCache();
        emit(current.copyWith(
          productSizes: current.productSizes.where((s) => s.id != event.id).toList(),
          actionStatus: const AttributeActionSuccess('O\'lcham o\'chirildi.'),
        ));
      },
    );
  }
  ProductAttributesLoaded? _requireLoaded(Emitter<ProductAttributesState> emit) {
    final current = state;
    if (current is ProductAttributesLoaded) return current;
    return null;
  }
}
