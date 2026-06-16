class ImportItemResultEntity {
  final bool createdProduct;
  final bool createdProductColor;
  final bool skipped;

  const ImportItemResultEntity({
    required this.createdProduct,
    required this.createdProductColor,
    required this.skipped,
  });
}
