import 'package:equatable/equatable.dart';

import '../../domain/entities/color_entity.dart';
import '../../domain/entities/product_quality_entity.dart';
import '../../domain/entities/product_type_entity.dart';

/// A single row parsed from an image filename.
class ParsedImportEntry extends Equatable {
  final String productName;
  final String colorName;

  /// Absolute path to the local image file selected by the user.
  /// Null if the entry was added without a file (edge case).
  final String? imagePath;

  const ParsedImportEntry({
    required this.productName,
    required this.colorName,
    this.imagePath,
  });

  @override
  List<Object?> get props => [productName, colorName, imagePath];
}

// ─── States ─────────────────────────────────────────────────────────────────

abstract class ImportProductsState extends Equatable {
  const ImportProductsState();

  @override
  List<Object?> get props => [];
}

class ImportProductsInitial extends ImportProductsState {
  const ImportProductsInitial();
}

class ImportProductsLoading extends ImportProductsState {
  const ImportProductsLoading();
}

class ImportProductsReady extends ImportProductsState {
  final List<ProductQualityEntity> qualities;
  final List<ProductTypeEntity> productTypes;
  final List<ColorEntity> colors;
  final List<ParsedImportEntry> entries;
  final int? selectedQualityId;
  final int? selectedProductTypeId;

  const ImportProductsReady({
    required this.qualities,
    required this.productTypes,
    this.colors = const [],
    this.entries = const [],
    this.selectedQualityId,
    this.selectedProductTypeId,
  });

  ImportProductsReady copyWith({
    List<ParsedImportEntry>? entries,
    int? selectedQualityId,
    int? selectedProductTypeId,
    bool clearQualityId = false,
    bool clearTypeId = false,
  }) {
    return ImportProductsReady(
      qualities: qualities,
      productTypes: productTypes,
      colors: colors,
      entries: entries ?? this.entries,
      selectedQualityId: clearQualityId ? null : (selectedQualityId ?? this.selectedQualityId),
      selectedProductTypeId: clearTypeId ? null : (selectedProductTypeId ?? this.selectedProductTypeId),
    );
  }

  @override
  List<Object?> get props =>
      [qualities, productTypes, colors, entries, selectedQualityId, selectedProductTypeId];
}

class ImportProductsSubmitting extends ImportProductsState {
  final List<ProductQualityEntity> qualities;
  final List<ProductTypeEntity> productTypes;
  final List<ColorEntity> colors;
  final List<ParsedImportEntry> entries;
  final int? selectedQualityId;
  final int? selectedProductTypeId;

  const ImportProductsSubmitting({
    required this.qualities,
    required this.productTypes,
    this.colors = const [],
    required this.entries,
    this.selectedQualityId,
    this.selectedProductTypeId,
  });

  @override
  List<Object?> get props => [
        qualities,
        productTypes,
        colors,
        entries,
        selectedQualityId,
        selectedProductTypeId,
      ];
}

class ImportProductsSuccess extends ImportProductsState {
  final int createdProducts;
  final int createdColors;
  final int skipped;

  const ImportProductsSuccess({
    required this.createdProducts,
    required this.createdColors,
    required this.skipped,
  });

  @override
  List<Object?> get props => [createdProducts, createdColors, skipped];
}

class ImportProductsFailure extends ImportProductsState {
  final String message;
  final List<ProductQualityEntity> qualities;
  final List<ProductTypeEntity> productTypes;
  final List<ColorEntity> colors;
  final List<ParsedImportEntry> entries;
  final int? selectedQualityId;
  final int? selectedProductTypeId;

  const ImportProductsFailure(
    this.message, {
    required this.qualities,
    required this.productTypes,
    this.colors = const [],
    required this.entries,
    this.selectedQualityId,
    this.selectedProductTypeId,
  });

  @override
  List<Object?> get props => [
        message,
        qualities,
        productTypes,
        colors,
        entries,
        selectedQualityId,
        selectedProductTypeId,
      ];
}
