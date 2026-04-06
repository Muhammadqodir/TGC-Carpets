import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_bloc.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_event.dart';
import 'package:tgc_client/features/clients/presentation/pages/clients_desktop_page.dart';
import 'package:tgc_client/features/clients/presentation/pages/clients_mobile_page.dart';

class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ClientsBloc>()..add(const ClientsLoadRequested()),
      child: const _AdaptiveClientsView(),
    );
  }
}

class _AdaptiveClientsView extends StatelessWidget {
  const _AdaptiveClientsView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return const ClientsDesktopPage();
        }
        return const ClientsMobilePage();
      },
    );
  }
}


