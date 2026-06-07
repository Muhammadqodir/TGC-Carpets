import 'package:equatable/equatable.dart';

class ProductTypeEntity extends Equatable {
  final int id;
  final String type;
  final String status;

  const ProductTypeEntity({
    required this.id,
    required this.type,
    this.status = 'active',
  });

  bool get isArchived => status == 'archived';

  ProductTypeEntity copyWith({int? id, String? type, String? status}) =>
      ProductTypeEntity(
        id: id ?? this.id,
        type: type ?? this.type,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [id, type, status];
}
