import 'package:equatable/equatable.dart';
import '../../domain/entities/scanned_item_entity.dart';

abstract class ScannerState extends Equatable {
  const ScannerState();
}

class ScannerInitial extends ScannerState {
  const ScannerInitial();

  @override
  List<Object?> get props => [];
}

class ScannerScanning extends ScannerState {
  const ScannerScanning();

  @override
  List<Object?> get props => [];
}

class ScannerLoaded extends ScannerState {
  final ScannedItemEntity item;

  const ScannerLoaded(this.item);

  @override
  List<Object?> get props => [item];
}

class ScannerError extends ScannerState {
  final String message;

  const ScannerError(this.message);

  @override
  List<Object?> get props => [message];
}
