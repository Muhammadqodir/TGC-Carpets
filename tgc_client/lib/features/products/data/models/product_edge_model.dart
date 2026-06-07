import '../../domain/entities/product_edge_entity.dart';

class ProductEdgeModel extends ProductEdgeEntity {
  const ProductEdgeModel({
    required super.id,
    required super.code,
    required super.title,
  });

  factory ProductEdgeModel.fromJson(Map<String, dynamic> json) =>
      ProductEdgeModel(
        id:    json['id']    as int,
        code:  json['code']  as String,
        title: json['title'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id':    id,
        'code':  code,
        'title': title,
      };
}
