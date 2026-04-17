import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/debits_bloc.dart';
import '../bloc/debits_event.dart';
import 'desktop/debits_desktop_page.dart';
import 'mobile/debits_mobile_page.dart';

/// Adaptive entry point for the Debits feature.
class DebitsPage extends StatelessWidget {
  const DebitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DebitsBloc>()..add(const DebitsLoadRequested()),
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
          return const DebitsDesktopPage();
        }
        return const DebitsMobilePage();
      },
    );
  }
}
