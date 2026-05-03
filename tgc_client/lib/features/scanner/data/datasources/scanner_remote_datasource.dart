import 'package:dio/dio.dart';
import '../models/scanned_item_model.dart';

abstract class ScannerRemoteDataSource {
  Future<ScannedItemModel> scanItem(String code);
}

class ScannerRemoteDataSourceImpl implements ScannerRemoteDataSource {
  final Dio dio;

  ScannerRemoteDataSourceImpl({required this.dio});

  @override
  Future<ScannedItemModel> scanItem(String code) async {
    final response = await dio.get(
      '/production-batches-scan',
      queryParameters: {'code': code},
    );

    return ScannedItemModel.fromJson(response.data['data']);
  }
}
