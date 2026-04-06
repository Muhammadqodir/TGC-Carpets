import 'package:equatable/equatable.dart';

class ProductTypeEntity extends Equatable {
  final int id;
  final String type;

  const ProductTypeEntity({required this.id, required this.type});

  @override
  List<Object?> get props => [id, type];
}
