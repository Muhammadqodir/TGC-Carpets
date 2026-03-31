import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/create_client_usecase.dart';
import 'client_form_event.dart';
import 'client_form_state.dart';

class ClientFormBloc extends Bloc<ClientFormEvent, ClientFormState> {
  final CreateClientUseCase createClientUseCase;

  ClientFormBloc({required this.createClientUseCase})
      : super(const ClientFormInitial()) {
    on<ClientFormSubmitted>(_onSubmitted);
  }

  Future<void> _onSubmitted(
    ClientFormSubmitted event,
    Emitter<ClientFormState> emit,
  ) async {
    emit(const ClientFormSubmitting());

    final result = await createClientUseCase(
      contactName: event.contactName,
      phone: event.phone,
      shopName: event.shopName,
      region: event.region,
      address: event.address,
      notes: event.notes,
    );

    result.fold(
      (failure) => emit(ClientFormFailure(failure.message)),
      (client) => emit(ClientFormSuccess(client)),
    );
  }
}
