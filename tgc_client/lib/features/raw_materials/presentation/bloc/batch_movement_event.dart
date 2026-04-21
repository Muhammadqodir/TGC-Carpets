import 'package:equatable/equatable.dart';

abstract class BatchMovementEvent extends Equatable {
  const BatchMovementEvent();

  @override
  List<Object?> get props => [];
}

class BatchMovementSubmitted extends BatchMovementEvent {
  final String dateTime;
  final String type; // 'received' | 'spent'
  final String? notes;
  final List<Map<String, dynamic>> items; // [{material_id, quantity}]

  const BatchMovementSubmitted({
    required this.dateTime,
    required this.type,
    this.notes,
    required this.items,
  });

  @override
  List<Object?> get props => [dateTime, type, items];
}
