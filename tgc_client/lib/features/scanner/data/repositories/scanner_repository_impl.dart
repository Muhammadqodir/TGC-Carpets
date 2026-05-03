import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/scanned_item_entity.dart';
import '../../domain/repositories/scanner_repository.dart';
import '../datasources/scanner_remote_datasource.dart';

class ScannerRepositoryImpl implements ScannerRepository {
  final ScannerRemoteDataSource remoteDataSource;

  ScannerRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, ScannedItemEntity>> scanItem(String code) async {
    try {
      final result = await remoteDataSource.scanItem(code);
      return Right(result);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const Left(ServerFailure('Mahsulot topilmadi'));
      }
      if (e.response?.statusCode == 400) {
        return Left(ServerFailure(
            e.response?.data['message'] ?? 'Noto\'g\'ri QR kod formati'));
      }
      return const Left(ServerFailure('Serverda xatolik yuz berdi'));
    } catch (e) {
      return const Left(ServerFailure('Kutilmagan xatolik yuz berdi'));
    }
  }
}
