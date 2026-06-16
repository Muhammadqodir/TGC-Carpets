import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/color_entity.dart';
import '../../domain/entities/product_quality_entity.dart';
import '../../domain/entities/product_type_entity.dart';
import '../../domain/usecases/create_product_color_usecase.dart';
import '../../domain/usecases/create_product_usecase.dart';
import '../../domain/usecases/get_colors_usecase.dart';
import '../../domain/usecases/get_product_qualities_usecase.dart';
import '../../domain/usecases/get_product_types_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import 'import_products_event.dart';
import 'import_products_state.dart';

class ImportProductsBloc
    extends Bloc<ImportProductsEvent, ImportProductsState> {
  final GetProductQualitiesUseCase getProductQualitiesUseCase;
  final GetProductTypesUseCase getProductTypesUseCase;
  final GetColorsUseCase getColorsUseCase;
  final GetProductsUseCase getProductsUseCase;
  final CreateProductUseCase createProductUseCase;
  final CreateProductColorUseCase createProductColorUseCase;

  ImportProductsBloc({
    required this.getProductQualitiesUseCase,
    required this.getProductTypesUseCase,
    required this.getColorsUseCase,
    required this.getProductsUseCase,
    required this.createProductUseCase,
    required this.createProductColorUseCase,
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
      getColorsUseCase(),
    ]);

    final qualities = results[0].fold(
      (_) => <ProductQualityEntity>[],
      (v) => (v as List<ProductQualityEntity>).where((q) => !q.isArchived).toList(),
    );
    final productTypes = results[1].fold(
      (_) => <ProductTypeEntity>[],
      (v) => (v as List<ProductTypeEntity>).where((t) => !t.isArchived).toList(),
    );
    final colors = results[2].fold(
      (_) => <ColorEntity>[],
      (v) => v as List<ColorEntity>,
    );

    emit(ImportProductsReady(
      qualities: qualities,
      productTypes: productTypes,
      colors: colors,
    ));
  }

  void _onEntriesAdded(
    ImportProductsEntriesAdded event,
    Emitter<ImportProductsState> emit,
  ) {
    final current = _currentReady();
    if (current == null) return;

    final combined = [...current.entries, ...event.entries];

    // Deduplicate by productName|colorName (case-insensitive key)
    final seen = <String>{};
    final deduped = combined.where((e) {
      return seen.add('${e.productName.toLowerCase()}|${e.colorName.toLowerCase()}');
    }).toList();

    emit(ImportProductsReady(
      qualities: current.qualities,
      productTypes: current.productTypes,
      colors: current.colors,
      entries: deduped,
      selectedQualityId: current.selectedQualityId,
      selectedProductTypeId: current.selectedProductTypeId,
    ));
  }

  void _onItemRemoved(
    ImportProductsItemRemoved event,
    Emitter<ImportProductsState> emit,
  ) {
    final current = _currentReady();
    if (current == null || event.index >= current.entries.length) return;

    final updated = List<ParsedImportEntry>.from(current.entries)
      ..removeAt(event.index);

    emit(ImportProductsReady(
      qualities: current.qualities,
      productTypes: current.productTypes,
      colors: current.colors,
      entries: updated,
      selectedQualityId: current.selectedQualityId,
      selectedProductTypeId: current.selectedProductTypeId,
    ));
  }

  void _onQualityChanged(
    ImportProductsQualityChanged event,
    Emitter<ImportProductsState> emit,
  ) {
    final current = _currentReady();
    if (current == null) return;

    emit(ImportProductsReady(
      qualities: current.qualities,
      productTypes: current.productTypes,
      colors: current.colors,
      entries: current.entries,
      selectedQualityId: event.qualityId,
      selectedProductTypeId: current.selectedProductTypeId,
    ));
  }

  void _onTypeChanged(
    ImportProductsTypeChanged event,
    Emitter<ImportProductsState> emit,
  ) {
    final current = _currentReady();
    if (current == null) return;

    emit(ImportProductsReady(
      qualities: current.qualities,
      productTypes: current.productTypes,
      colors: current.colors,
      entries: current.entries,
      selectedQualityId: current.selectedQualityId,
      selectedProductTypeId: event.typeId,
    ));
  }

  Future<void> _onSubmitted(
    ImportProductsSubmitted event,
    Emitter<ImportProductsState> emit,
  ) async {
    final current = _currentReady();
    if (current == null || current.entries.isEmpty) return;

    final totalItems = current.entries.length;

    emit(ImportProductsSubmitting(
      qualities: current.qualities,
      productTypes: current.productTypes,
      colors: current.colors,
      entries: current.entries,
      selectedQualityId: current.selectedQualityId,
      selectedProductTypeId: current.selectedProductTypeId,
      progress: 0,
      total: totalItems,
    ));

    // Group entries by product name, preserving original casing + imagePath per color.
    final grouped = <String,
        ({
          String originalName,
          List<({String colorName, String? imagePath})> colorEntries,
        })>{};

    for (final entry in current.entries) {
      final key = entry.productName.toLowerCase();
      if (grouped.containsKey(key)) {
        grouped[key]!.colorEntries.add(
          (colorName: entry.colorName, imagePath: entry.imagePath),
        );
      } else {
        grouped[key] = (
          originalName: entry.productName,
          colorEntries: [
            (colorName: entry.colorName, imagePath: entry.imagePath)
          ],
        );
      }
    }

    int processed = 0;
    int createdProducts = 0;
    int createdColors = 0;
    int skipped = 0;

    try {
      for (final groupEntry in grouped.entries) {
        final originalName = groupEntry.value.originalName;
        final colorEntries = groupEntry.value.colorEntries;

        // ── Step 1: find or create the product (backend deduplicates by name) ──
        final productResult = await createProductUseCase(
          name: originalName,
          productTypeId: current.selectedProductTypeId,
          productQualityId: current.selectedQualityId,
          unit: 'piece',
        );

        if (productResult.isLeft()) {
          skipped += colorEntries.length;
          processed += colorEntries.length;
          emit(ImportProductsSubmitting(
            qualities: current.qualities,
            productTypes: current.productTypes,
            colors: current.colors,
            entries: current.entries,
            selectedQualityId: current.selectedQualityId,
            selectedProductTypeId: current.selectedProductTypeId,
            progress: processed,
            total: totalItems,
          ));
          continue;
        }

        final product = productResult.fold((_) => throw StateError('unreachable'), (p) => p);
        createdProducts++;

        // ── Step 2: add colors one by one (backend deduplicates by product+color) ──
        for (final colorEntry in colorEntries) {
          ColorEntity? matchedColor;
          for (final c in current.colors) {
            if (c.name.toLowerCase() == colorEntry.colorName.toLowerCase()) {
              matchedColor = c;
              break;
            }
          }

          if (matchedColor == null) {
            skipped++;
            processed++;
            emit(ImportProductsSubmitting(
              qualities: current.qualities,
              productTypes: current.productTypes,
              colors: current.colors,
              entries: current.entries,
              selectedQualityId: current.selectedQualityId,
              selectedProductTypeId: current.selectedProductTypeId,
              progress: processed,
              total: totalItems,
            ));
            continue;
          }

          // Resize image if it's too large (max 1200px on either axis)
          String? uploadPath = colorEntry.imagePath;
          if (uploadPath != null) {
            uploadPath = await _resizeImageIfNeeded(uploadPath);
          }

          final result = await createProductColorUseCase(
            productId: product.id,
            colorId: matchedColor.id,
            imagePath: uploadPath,
          );

          result.fold(
            (_) => skipped++,
            (_) => createdColors++,
          );

          processed++;
          emit(ImportProductsSubmitting(
            qualities: current.qualities,
            productTypes: current.productTypes,
            colors: current.colors,
            entries: current.entries,
            selectedQualityId: current.selectedQualityId,
            selectedProductTypeId: current.selectedProductTypeId,
            progress: processed,
            total: totalItems,
          ));
        }
      }
    } catch (e) {
      emit(ImportProductsFailure(
        'Import jarayonida kutilmagan xato: $e',
        qualities: current.qualities,
        productTypes: current.productTypes,
        colors: current.colors,
        entries: current.entries,
        selectedQualityId: current.selectedQualityId,
        selectedProductTypeId: current.selectedProductTypeId,
      ));
      return;
    }

    emit(ImportProductsSuccess(
      createdProducts: createdProducts,
      createdColors: createdColors,
      skipped: skipped,
    ));
  }

  // ─── Image resize helper ─────────────────────────────────────────────────

  /// Resizes the image at [filePath] so neither dimension exceeds 1200 px.
  /// Returns the original path if no resize is needed, or the path to a
  /// temporary PNG file when resizing was performed.
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
      final targetWidth = (w * scale).round();
      final targetHeight = (h * scale).round();

      final codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      descriptor.dispose();
      buffer.dispose();

      final frame = await codec.getNextFrame();
      final image = frame.image;
      codec.dispose();

      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) return filePath;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/tgc_import_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(byteData.buffer.asUint8List());
      return tempFile.path;
    } catch (_) {
      // On any error, fall back to the original file
      return filePath;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  /// Returns the current ready state regardless of whether it is [ImportProductsReady]
  /// or [ImportProductsFailure] (recovery).
  ImportProductsReady? _currentReady() {
    final s = state;
    if (s is ImportProductsReady) return s;
    if (s is ImportProductsFailure) {
      return ImportProductsReady(
        qualities: s.qualities,
        productTypes: s.productTypes,
        colors: s.colors,
        entries: s.entries,
        selectedQualityId: s.selectedQualityId,
        selectedProductTypeId: s.selectedProductTypeId,
      );
    }
    return null;
  }
}
