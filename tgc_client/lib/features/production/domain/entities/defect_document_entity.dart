import 'package:equatable/equatable.dart';

class DefectDocumentPhotoEntity extends Equatable {
  final int id;
  final String url;
  final String path;

  const DefectDocumentPhotoEntity({
    required this.id,
    required this.url,
    required this.path,
  });

  @override
  List<Object?> get props => [id, url, path];
}

class DefectDocumentBatchItemRef extends Equatable {
  final int id;
  final int plannedQuantity;
  final String? productName;
  final String? colorName;
  final String? imageUrl;
  final int? sizeLength;
  final int? sizeWidth;

  const DefectDocumentBatchItemRef({
    required this.id,
    required this.plannedQuantity,
    this.productName,
    this.colorName,
    this.imageUrl,
    this.sizeLength,
    this.sizeWidth,
  });

  @override
  List<Object?> get props =>
      [id, plannedQuantity, productName, colorName, imageUrl, sizeLength, sizeWidth];
}

class DefectDocumentItemEntity extends Equatable {
  final int id;
  final int defectDocumentId;
  final int productionBatchItemId;
  final int quantity;
  final DefectDocumentBatchItemRef? batchItem;

  const DefectDocumentItemEntity({
    required this.id,
    required this.defectDocumentId,
    required this.productionBatchItemId,
    required this.quantity,
    this.batchItem,
  });

  @override
  List<Object?> get props =>
      [id, defectDocumentId, productionBatchItemId, quantity, batchItem];
}

class DefectDocumentEntity extends Equatable {
  final int id;
  final int productionBatchId;
  final DateTime datetime;
  final String description;
  final String? userName;
  final int? userId;
  final List<DefectDocumentItemEntity> items;
  final List<DefectDocumentPhotoEntity> photos;
  final DateTime createdAt;

  const DefectDocumentEntity({
    required this.id,
    required this.productionBatchId,
    required this.datetime,
    required this.description,
    this.userName,
    this.userId,
    this.items = const [],
    this.photos = const [],
    required this.createdAt,
  });

  int get totalDefectQuantity => items.fold(0, (s, i) => s + i.quantity);

  @override
  List<Object?> get props => [
        id,
        productionBatchId,
        datetime,
        description,
        userName,
        userId,
        items,
        photos,
        createdAt,
      ];
}
