import 'package:equatable/equatable.dart';

abstract class ScannerEvent extends Equatable {
  const ScannerEvent();
}

class ScannerCodeScanned extends ScannerEvent {
  final String code;

  const ScannerCodeScanned(this.code);

  @override
  List<Object?> get props => [code];
}

class ScannerResetRequested extends ScannerEvent {
  const ScannerResetRequested();

  @override
  List<Object?> get props => [];
}
