import 'package:equatable/equatable.dart';

abstract class ProductAttributesEvent extends Equatable {
  const ProductAttributesEvent();

  @override
  List<Object?> get props => [];
}

// ── Load ──────────────────────────────────────────────────────────────────────

class ProductAttributesLoadRequested extends ProductAttributesEvent {
  const ProductAttributesLoadRequested();
}

class ProductAttributesRefreshRequested extends ProductAttributesEvent {
  const ProductAttributesRefreshRequested();
}

// ── Colors ────────────────────────────────────────────────────────────────────

class ColorCreateRequested extends ProductAttributesEvent {
  final String name;
  const ColorCreateRequested(this.name);
  @override
  List<Object?> get props => [name];
}

class ColorUpdateRequested extends ProductAttributesEvent {
  final int id;
  final String name;
  const ColorUpdateRequested({required this.id, required this.name});
  @override
  List<Object?> get props => [id, name];
}

class ColorDeleteRequested extends ProductAttributesEvent {
  final int id;
  final int? replaceWithId;
  const ColorDeleteRequested(this.id, {this.replaceWithId});
  @override
  List<Object?> get props => [id, replaceWithId];
}

// ── Product Types ─────────────────────────────────────────────────────────────

class ProductTypeCreateRequested extends ProductAttributesEvent {
  final String type;
  final bool isPrintable;
  const ProductTypeCreateRequested(this.type, {this.isPrintable = true});
  @override
  List<Object?> get props => [type, isPrintable];
}

class ProductTypeUpdateRequested extends ProductAttributesEvent {
  final int id;
  final String type;
  final bool isPrintable;
  const ProductTypeUpdateRequested({required this.id, required this.type, this.isPrintable = true});
  @override
  List<Object?> get props => [id, type, isPrintable];
}

class ProductTypeDeleteRequested extends ProductAttributesEvent {
  final int id;
  final int? replaceWithId;
  const ProductTypeDeleteRequested(this.id, {this.replaceWithId});
  @override
  List<Object?> get props => [id, replaceWithId];
}

class ProductTypeArchiveToggleRequested extends ProductAttributesEvent {
  final int id;
  final bool archive;
  const ProductTypeArchiveToggleRequested({required this.id, required this.archive});
  @override
  List<Object?> get props => [id, archive];
}

// ── Product Qualities ─────────────────────────────────────────────────────────

class ProductQualityCreateRequested extends ProductAttributesEvent {
  final String qualityName;
  final int? density;
  const ProductQualityCreateRequested({required this.qualityName, this.density});
  @override
  List<Object?> get props => [qualityName, density];
}

class ProductQualityUpdateRequested extends ProductAttributesEvent {
  final int id;
  final String qualityName;
  final int? density;
  const ProductQualityUpdateRequested({required this.id, required this.qualityName, this.density});
  @override
  List<Object?> get props => [id, qualityName, density];
}

class ProductQualityDeleteRequested extends ProductAttributesEvent {
  final int id;
  final int? replaceWithId;
  const ProductQualityDeleteRequested(this.id, {this.replaceWithId});
  @override
  List<Object?> get props => [id, replaceWithId];
}

class ProductQualityArchiveToggleRequested extends ProductAttributesEvent {
  final int id;
  final bool archive;
  const ProductQualityArchiveToggleRequested({required this.id, required this.archive});
  @override
  List<Object?> get props => [id, archive];
}

// ── Product Sizes ─────────────────────────────────────────────────────────────

class ProductSizeCreateRequested extends ProductAttributesEvent {
  final int length;
  final int width;
  final int productTypeId;
  const ProductSizeCreateRequested({required this.length, required this.width, required this.productTypeId});
  @override
  List<Object?> get props => [length, width, productTypeId];
}

class ProductSizeUpdateRequested extends ProductAttributesEvent {
  final int id;
  final int length;
  final int width;
  final int productTypeId;
  const ProductSizeUpdateRequested({required this.id, required this.length, required this.width, required this.productTypeId});
  @override
  List<Object?> get props => [id, length, width, productTypeId];
}

class ProductSizeDeleteRequested extends ProductAttributesEvent {
  final int id;
  final int? replaceWithId;
  const ProductSizeDeleteRequested(this.id, {this.replaceWithId});
  @override
  List<Object?> get props => [id];
}

// ── Product Edges ─────────────────────────────────────────────────────────────

class ProductEdgeCreateRequested extends ProductAttributesEvent {
  final String code;
  final String title;
  const ProductEdgeCreateRequested({required this.code, required this.title});
  @override
  List<Object?> get props => [code, title];
}

class ProductEdgeUpdateRequested extends ProductAttributesEvent {
  final int id;
  final String code;
  final String title;
  const ProductEdgeUpdateRequested({required this.id, required this.code, required this.title});
  @override
  List<Object?> get props => [id, code, title];
}

class ProductEdgeDeleteRequested extends ProductAttributesEvent {
  final int id;
  final int? replaceWithId;
  const ProductEdgeDeleteRequested(this.id, {this.replaceWithId});
  @override
  List<Object?> get props => [id, replaceWithId];
}
