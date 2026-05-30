import 'package:equatable/equatable.dart';

import 'import_products_state.dart';

abstract class ImportProductsEvent extends Equatable {
  const ImportProductsEvent();

  @override
  List<Object?> get props => [];
}

/// Triggers initial data load (qualities + colors).
class ImportProductsStarted extends ImportProductsEvent {
  const ImportProductsStarted();
}

/// Adds new parsed entries (deduplication applied in BLoC).
class ImportProductsEntriesAdded extends ImportProductsEvent {
  final List<ParsedImportEntry> entries;

  const ImportProductsEntriesAdded(this.entries);

  @override
  List<Object?> get props => [entries];
}

/// Removes an entry from the table at the given index.
class ImportProductsItemRemoved extends ImportProductsEvent {
  final int index;

  const ImportProductsItemRemoved(this.index);

  @override
  List<Object?> get props => [index];
}

/// Updates the quality selection for all new products.
class ImportProductsQualityChanged extends ImportProductsEvent {
  final int? qualityId;

  const ImportProductsQualityChanged(this.qualityId);

  @override
  List<Object?> get props => [qualityId];
}

/// Updates the type selection for all new products.
class ImportProductsTypeChanged extends ImportProductsEvent {
  final int? typeId;

  const ImportProductsTypeChanged(this.typeId);

  @override
  List<Object?> get props => [typeId];
}

/// Triggers the import: creates products / product-colors as needed.
class ImportProductsSubmitted extends ImportProductsEvent {
  const ImportProductsSubmitted();
}
