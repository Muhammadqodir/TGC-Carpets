import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/change_password_usecase.dart';
import 'settings_event.dart';
import 'settings_state.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final ChangePasswordUseCase changePasswordUseCase;

  SettingsBloc({required this.changePasswordUseCase}) : super(SettingsInitial()) {
    on<ChangePasswordSubmitted>(_onChangePasswordSubmitted);
  }

  Future<void> _onChangePasswordSubmitted(
    ChangePasswordSubmitted event,
    Emitter<SettingsState> emit,
  ) async {
    emit(SettingsSubmitting());
    final result = await changePasswordUseCase(
      currentPassword: event.currentPassword,
      newPassword: event.newPassword,
    );
    result.fold(
      (failure) => emit(SettingsFailure(failure.message)),
      (_) => emit(SettingsSuccess('Parol muvaffaqiyatli o\'zgartirildi.')),
    );
  }
}
