import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/raw_materials_bloc.dart';
import '../bloc/raw_materials_event.dart';
import 'raw_materials_desktop_page.dart';
import 'raw_materials_mobile_page.dart';

/// Adaptive entry point: dispatches to desktop or mobile view.
class RawMaterialsPage extends StatelessWidget {
  const RawMaterialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<RawMaterialsBloc>()..add(const RawMaterialsLoadRequested()),
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
          return const RawMaterialsDesktopPage();
        }
        return const RawMaterialsMobilePage();
      },
    );
  }
}
