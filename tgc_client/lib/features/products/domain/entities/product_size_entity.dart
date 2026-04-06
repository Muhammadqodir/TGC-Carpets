import 'package:equatable/equatable.dart';

class ProductSizeEntity extends Equatable {
  final int id;
  final int length;
  final int width;
  final int productTypeId;

  const ProductSizeEntity({
    required this.id,
    required this.length,
    required this.width,
    required this.productTypeId,
  });

  String get dimensions => '${length}x$width';

  @override
  List<Object?> get props => [id, length, width, productTypeId];
}
