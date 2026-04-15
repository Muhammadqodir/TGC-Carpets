import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/payments_bloc.dart';
import '../bloc/payments_event.dart';
import 'desktop/payments_desktop_page.dart';
import 'mobile/payments_mobile_page.dart';

/// Adaptive entry point for the Payments feature.
class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<PaymentsBloc>()..add(const PaymentsLoadRequested()),
      child: const _AdaptiveView(),
    );
  }
}

class _AdaptiveView extends StatelessWidget {
  const _AdaptiveView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return const PaymentsDesktopPage();
        }
        return const PaymentsMobilePage();
      },
    );
  }
}
