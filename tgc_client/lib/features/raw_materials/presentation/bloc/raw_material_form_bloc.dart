import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/create_raw_material_usecase.dart';
import 'raw_material_form_event.dart';
import 'raw_material_form_state.dart';

class RawMaterialFormBloc
    extends Bloc<RawMaterialFormEvent, RawMaterialFormState> {
  final CreateRawMaterialUseCase createRawMaterialUseCase;

  RawMaterialFormBloc({required this.createRawMaterialUseCase})
      : super(const RawMaterialFormInitial()) {
    on<RawMaterialFormSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    RawMaterialFormSubmitted event,
    Emitter<RawMaterialFormState> emit,
  ) async {
    emit(const RawMaterialFormLoading());

    final result = await createRawMaterialUseCase(
      name: event.name,
      type: event.type,
      unit: event.unit,
    );

    result.fold(
      (failure) => emit(RawMaterialFormError(failure.message)),
      (material) => emit(RawMaterialFormSuccess(material)),
    );
  }
}
