class ImportProductItem {
  final String productName;
  final String colorName;
  final String? imagePath;

  const ImportProductItem({
    required this.productName,
    required this.colorName,
    this.imagePath,
  });
}
