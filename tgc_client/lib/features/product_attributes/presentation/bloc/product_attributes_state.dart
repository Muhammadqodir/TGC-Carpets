import 'package:equatable/equatable.dart';
import '../../../products/domain/entities/color_entity.dart';
import '../../../products/domain/entities/product_quality_entity.dart';
import '../../../products/domain/entities/product_size_entity.dart';
import '../../../products/domain/entities/product_type_entity.dart';

// ── Action status (shared across all tabs) ────────────────────────────────────

sealed class AttributeActionStatus extends Equatable {
  const AttributeActionStatus();
}

class AttributeActionIdle extends AttributeActionStatus {
  const AttributeActionIdle();
  @override
  List<Object?> get props => [];
}

class AttributeActionPending extends AttributeActionStatus {
  const AttributeActionPending();
  @override
  List<Object?> get props => [];
}

class AttributeActionSuccess extends AttributeActionStatus {
  final String message;
  const AttributeActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class AttributeActionFailure extends AttributeActionStatus {
  final String message;
  const AttributeActionFailure(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Page states ───────────────────────────────────────────────────────────────

abstract class ProductAttributesState extends Equatable {
  const ProductAttributesState();

  @override
  List<Object?> get props => [];
}

class ProductAttributesInitial extends ProductAttributesState {
  const ProductAttributesInitial();
}

class ProductAttributesLoading extends ProductAttributesState {
  const ProductAttributesLoading();
}

class ProductAttributesLoaded extends ProductAttributesState {
  final List<ColorEntity> colors;
  final List<ProductTypeEntity> productTypes;
  final List<ProductQualityEntity> productQualities;
  final List<ProductSizeEntity> productSizes;
  final AttributeActionStatus actionStatus;

  const ProductAttributesLoaded({
    required this.colors,
    required this.productTypes,
    required this.productQualities,
    required this.productSizes,
    this.actionStatus = const AttributeActionIdle(),
  });

  ProductAttributesLoaded copyWith({
    List<ColorEntity>? colors,
    List<ProductTypeEntity>? productTypes,
    List<ProductQualityEntity>? productQualities,
    List<ProductSizeEntity>? productSizes,
    AttributeActionStatus? actionStatus,
  }) =>
      ProductAttributesLoaded(
        colors: colors ?? this.colors,
        productTypes: productTypes ?? this.productTypes,
        productQualities: productQualities ?? this.productQualities,
        productSizes: productSizes ?? this.productSizes,
        actionStatus: actionStatus ?? this.actionStatus,
      );

  @override
  List<Object?> get props => [colors, productTypes, productQualities, productSizes, actionStatus];
}

class ProductAttributesError extends ProductAttributesState {
  final String message;
  const ProductAttributesError(this.message);
  @override
  List<Object?> get props => [message];
}
