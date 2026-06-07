import 'package:equatable/equatable.dart';

class ProductQualityEntity extends Equatable {
  final int id;
  final String qualityName;
  final int? density;
  final String status;

  const ProductQualityEntity({
    required this.id,
    required this.qualityName,
    this.density,
    this.status = 'active',
  });

  bool get isArchived => status == 'archived';

  ProductQualityEntity copyWith({int? id, String? qualityName, int? density, String? status}) =>
      ProductQualityEntity(
        id: id ?? this.id,
        qualityName: qualityName ?? this.qualityName,
        density: density ?? this.density,
        status: status ?? this.status,
      );

  @override
  List<Object?> get props => [id, qualityName, density, status];
}
