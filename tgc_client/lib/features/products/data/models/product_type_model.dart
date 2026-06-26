import '../../domain/entities/product_type_entity.dart';

class ProductTypeModel extends ProductTypeEntity {
  const ProductTypeModel({required super.id, required super.type, super.status, super.isPrintable = true});

  factory ProductTypeModel.fromJson(Map<String, dynamic> json) =>
      ProductTypeModel(
        id: json['id'] as int,
        type: json['type'] as String,
        status: json['status'] as String? ?? 'active',
        isPrintable: json['is_printable'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'status': status, 'is_printable': isPrintable};
}
