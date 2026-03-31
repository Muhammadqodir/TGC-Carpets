import 'package:equatable/equatable.dart';

class ProductEntity extends Equatable {
  final int id;
  final String uuid;
  final String name;
  final String? skuCode;
  final String? barcode;
  final int length;
  final int width;
  final String quality;
  final int density;
  final String color;
  final String? edge;
  final String unit;
  final String status;
  final String? imageUrl;
  final int? stock;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductEntity({
    required this.id,
    required this.uuid,
    required this.name,
    this.skuCode,
    this.barcode,
    required this.length,
    required this.width,
    required this.quality,
    required this.density,
    required this.color,
    this.edge,
    required this.unit,
    required this.status,
    this.imageUrl,
    this.stock,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';
  String get dimensions => '${length}x$width';

  @override
  List<Object?> get props => [
        id,
        uuid,
        name,
        skuCode,
        barcode,
        length,
        width,
        quality,
        density,
        color,
        edge,
        unit,
        status,
        imageUrl,
        stock,
        createdAt,
        updatedAt,
      ];
}
