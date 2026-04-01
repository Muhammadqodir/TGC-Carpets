import 'package:equatable/equatable.dart';

abstract class SettingsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SettingsInitial extends SettingsState {}

class SettingsSubmitting extends SettingsState {}

class SettingsSuccess extends SettingsState {
  final String message;
  SettingsSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class SettingsFailure extends SettingsState {
  final String message;
  SettingsFailure(this.message);

  @override
  List<Object?> get props => [message];
}
