import 'package:equatable/equatable.dart';

class ProductColorEntity extends Equatable {
  final int id;
  final int colorId;
  final String colorName;
  final String? imageUrl;

  const ProductColorEntity({
    required this.id,
    required this.colorId,
    required this.colorName,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [id, colorId, colorName, imageUrl];
}
