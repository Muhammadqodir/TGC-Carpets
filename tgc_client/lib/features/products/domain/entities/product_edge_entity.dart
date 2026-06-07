import 'package:equatable/equatable.dart';

class ProductEdgeEntity extends Equatable {
  final int id;
  final String code;
  final String title;

  const ProductEdgeEntity({
    required this.id,
    required this.code,
    required this.title,
  });

  @override
  List<Object?> get props => [id, code, title];
}
