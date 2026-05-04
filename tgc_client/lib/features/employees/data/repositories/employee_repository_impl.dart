import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/models/paginated_response.dart';
import '../../domain/entities/employee_entity.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_remote_datasource.dart';

class EmployeeRepositoryImpl implements EmployeeRepository {
  final EmployeeRemoteDataSource remoteDataSource;
  const EmployeeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, PaginatedResponse<EmployeeEntity>>> getEmployees({
    String? search,
    String? role,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final result = await remoteDataSource.getEmployees(
          search: search, role: role, page: page, perPage: perPage);
      return Right(PaginatedResponse<EmployeeEntity>(
        data: result.data,
        currentPage: result.currentPage,
        lastPage: result.lastPage,
        perPage: result.perPage,
        total: result.total,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, EmployeeEntity>> createEmployee({
    required String name,
    required String email,
    String? phone,
    required String password,
    required List<String> roles,
  }) async {
    try {
      return Right(await remoteDataSource.createEmployee(
        name: name, email: email, phone: phone, password: password, roles: roles,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, EmployeeEntity>> updateEmployee({
    required int id,
    String? name,
    String? email,
    String? phone,
    String? password,
    List<String>? roles,
  }) async {
    try {
      return Right(await remoteDataSource.updateEmployee(
        id: id, name: name, email: email, phone: phone, password: password, roles: roles,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEmployee({required int id}) async {
    try {
      await remoteDataSource.deleteEmployee(id: id);
      return const Right(null);
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } on UnauthorizedException {
      return const Left(UnauthorizedFailure());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message, statusCode: e.statusCode));
    }
  }
}
