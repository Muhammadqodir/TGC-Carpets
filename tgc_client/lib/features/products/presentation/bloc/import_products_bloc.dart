import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/import_product_item.dart';
import '../../domain/entities/product_quality_entity.dart';
import '../../domain/entities/product_type_entity.dart';
import '../../domain/usecases/get_product_qualities_usecase.dart';
import '../../domain/usecases/get_product_types_usecase.dart';
import '../../domain/usecases/import_products_usecase.dart';
import 'import_products_event.dart';
import 'import_products_state.dart';

class ImportProductsBloc
    extends Bloc<ImportProductsEvent, ImportProductsState> {
  final GetProductQualitiesUseCase getProductQualitiesUseCase;
  final GetProductTypesUseCase getProductTypesUseCase;
  final ImportProductsUseCase importProductsUseCase;

  ImportProductsBloc({
    required this.getProductQualitiesUseCase,
    required this.getProductTypesUseCase,
    required this.importProductsUseCase,
  }) : super(const ImportProductsInitial()) {
    on<ImportProductsStarted>(_onStarted);
    on<ImportProductsEntriesAdded>(_onEntriesAdded);
    on<ImportProductsItemRemoved>(_onItemRemoved);
    on<ImportProductsQualityChanged>(_onQualityChanged);
    on<ImportProductsTypeChanged>(_onTypeChanged);
    on<ImportProductsSubmitted>(_onSubmitted);
  }

  // ─── Handlers ────────────────────────────────────────────────────────────

  Future<void> _onStarted(
    ImportProductsStarted event,
    Emitter<ImportProductsState> emit,
  ) async {
    emit(const ImportProductsLoading());

    final results = await Future.wait([
      getProductQualitiesUseCase(),
      getProductTypesUseCase(),
    ]);

    final qualities = results[0].fold(
      (_) => <ProductQualityEntity>[],
      (v) => (v as List<ProductQualityEntity>).where((q) => !q.isArchived).toList(),
    );
    final productTypes = results[1].fold(
      (_) => <ProductTypeEntity>[],
      (v) => (v as List<ProductTypeEntity>).where((t) => !t.isArchived).toList(),
    );

    emit(ImportProductsReady(
      qualities: qualities,
      productTypes: productTypes,
    ));
  }

  void _onEntriesAdded(
    ImportProductsEntriesAdded event,
    Emitter<ImportProductsState> emit,
  ) {
    final current = _currentReady();
    if (current == null) return;

    final combined = [...current.entries, ...event.entries];

    final seen = <String>{};
    final deduped = combined.where((e) {
      return seen.add('${e.productName.toLowerCase()}|${e.colorName.toLowerCase()}');
    }).toList();

    emit(current.copyWith(entries: deduped));
  }

  void _onItemRemoved(
    ImportProductsItemRemoved event,
    Emitter<ImportProductsState> emit,
  ) {
    final current = _currentReady();
    if (current == null || event.index >= current.entries.length) return;

    final updated = List<ParsedImportEntry>.from(current.entries)
      ..removeAt(event.index);

    emit(current.copyWith(entries: updated));
  }

  void _onQualityChanged(
    ImportProductsQualityChanged event,
    Emitter<ImportProductsState> emit,
  ) {
    final current = _currentReady();
    if (current == null) return;
    emit(current.copyWith(selectedQualityId: event.qualityId, clearQualityId: event.qualityId == null));
  }

  void _onTypeChanged(
    ImportProductsTypeChanged event,
    Emitter<ImportProductsState> emit,
  ) {
    final current = _currentReady();
    if (current == null) return;
    emit(current.copyWith(selectedProductTypeId: event.typeId, clearTypeId: event.typeId == null));
  }

  Future<void> _onSubmitted(
    ImportProductsSubmitted event,
    Emitter<ImportProductsState> emit,
  ) async {
    final current = _currentReady();
    if (current == null || current.entries.isEmpty) return;

    final total = current.entries.length;
    int createdProducts = 0;
    int createdColors = 0;
    int skipped = 0;

    for (var i = 0; i < total; i++) {
      final entry = current.entries[i];

      emit(ImportProductsSubmitting(
        qualities: current.qualities,
        productTypes: current.productTypes,
        entries: current.entries,
        selectedQualityId: current.selectedQualityId,
        selectedProductTypeId: current.selectedProductTypeId,
        progress: i,
        total: total,
      ));

      // Resize image client-side before upload (max 1200 px on either axis).
      String? imagePath = entry.imagePath;
      if (imagePath != null) {
        imagePath = await _resizeImageIfNeeded(imagePath);
      }

      final result = await importProductsUseCase(
        productQualityId: current.selectedQualityId,
        productTypeId: current.selectedProductTypeId,
        item: ImportProductItem(
          productName: entry.productName,
          colorName: entry.colorName,
          imagePath: imagePath,
        ),
      );

      result.fold(
        (f) => skipped++,
        (r) {
          if (r.createdProduct) createdProducts++;
          if (r.createdProductColor) createdColors++;
          if (r.skipped) skipped++;
        },
      );
    }

    emit(ImportProductsSuccess(
      createdProducts: createdProducts,
      createdColors: createdColors,
      skipped: skipped,
    ));
  }

  // ─── Image resize helper ─────────────────────────────────────────────────

  static Future<String> _resizeImageIfNeeded(String filePath) async {
    const maxDimension = 1200;
    try {
      final bytes = await File(filePath).readAsBytes();
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);

      final w = descriptor.width;
      final h = descriptor.height;

      if (w <= maxDimension && h <= maxDimension) {
        descriptor.dispose();
        buffer.dispose();
        return filePath;
      }

      final scale = maxDimension / (w > h ? w : h);
      final codec = await descriptor.instantiateCodec(
        targetWidth: (w * scale).round(),
        targetHeight: (h * scale).round(),
      );
      descriptor.dispose();
      buffer.dispose();

      final frame = await codec.getNextFrame();
      final image = frame.image;
      codec.dispose();

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) return filePath;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/tgc_import_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      return tempFile.path;
    } catch (_) {
      return filePath;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  ImportProductsReady? _currentReady() {
    final s = state;
    if (s is ImportProductsReady) return s;
    if (s is ImportProductsFailure) {
      return ImportProductsReady(
        qualities: s.qualities,
        productTypes: s.productTypes,
        entries: s.entries,
        selectedQualityId: s.selectedQualityId,
        selectedProductTypeId: s.selectedProductTypeId,
      );
    }
    return null;
  }
}
