import 'package:equatable/equatable.dart';

import '../../domain/entities/raw_material_entity.dart';

abstract class RawMaterialsState extends Equatable {
  const RawMaterialsState();

  @override
  List<Object?> get props => [];
}

class RawMaterialsInitial extends RawMaterialsState {
  const RawMaterialsInitial();
}

class RawMaterialsLoading extends RawMaterialsState {
  const RawMaterialsLoading();
}

class RawMaterialsLoaded extends RawMaterialsState {
  final List<RawMaterialEntity> materials;
  final bool hasNextPage;
  final bool isLoadingMore;
  final String? activeType;

  const RawMaterialsLoaded({
    required this.materials,
    required this.hasNextPage,
    this.isLoadingMore = false,
    this.activeType,
  });

  RawMaterialsLoaded copyWith({
    List<RawMaterialEntity>? materials,
    bool? hasNextPage,
    bool? isLoadingMore,
    String? activeType,
    bool clearType = false,
  }) =>
      RawMaterialsLoaded(
        materials:    materials    ?? this.materials,
        hasNextPage:  hasNextPage  ?? this.hasNextPage,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        activeType:   clearType ? null : (activeType ?? this.activeType),
      );

  @override
  List<Object?> get props => [materials, hasNextPage, isLoadingMore, activeType];
}

class RawMaterialsError extends RawMaterialsState {
  final String message;

  const RawMaterialsError(this.message);

  @override
  List<Object?> get props => [message];
}
