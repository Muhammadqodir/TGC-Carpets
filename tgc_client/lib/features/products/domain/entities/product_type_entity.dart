import 'package:equatable/equatable.dart';

class ProductTypeEntity extends Equatable {
  final int id;
  final String type;
  final String status;
  final bool isPrintable;

  const ProductTypeEntity({
    required this.id,
    required this.type,
    this.status = 'active',
    this.isPrintable = true,
  });

  bool get isArchived => status == 'archived';

  ProductTypeEntity copyWith({int? id, String? type, String? status, bool? isPrintable}) =>
      ProductTypeEntity(
        id: id ?? this.id,
        type: type ?? this.type,
        status: status ?? this.status,
        isPrintable: isPrintable ?? this.isPrintable,
      );

  @override
  List<Object?> get props => [id, type, status, isPrintable];
}
