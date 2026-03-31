import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  final int? statusCode;

  const ServerFailure(super.message, {this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure() : super('Login yoki parol noto\'g\'ri.');
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Internetga ulanishda xatolik yuz berdi.']);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
