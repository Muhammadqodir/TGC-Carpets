class ImportSummaryEntity {
  final int createdProducts;
  final int createdProductColors;
  final int skipped;

  const ImportSummaryEntity({
    required this.createdProducts,
    required this.createdProductColors,
    required this.skipped,
  });
}
