import 'package:equatable/equatable.dart';

class ProductQualityEntity extends Equatable {
  final int id;
  final String qualityName;
  final int? density;

  const ProductQualityEntity({
    required this.id,
    required this.qualityName,
    this.density,
  });

  @override
  List<Object?> get props => [id, qualityName, density];
}
