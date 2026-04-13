import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/constants/app_constants.dart';

import '../../../../core/di/injection.dart';
import '../bloc/shipments_bloc.dart';
import '../bloc/shipments_event.dart';
import 'desktop/shipments_desktop_page.dart';

/// Adaptive entry point — currently renders desktop table for all widths
/// ≥ [AppConstants.desktopBreakpoint]; falls back to same table on smaller
/// screens (a dedicated mobile card view can be added later).
class ShipmentsPage extends StatelessWidget {
  const ShipmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ShipmentsBloc>()..add(const ShipmentsLoadRequested()),
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
          return const ShipmentsDesktopPage();
        }
        // Reuse desktop layout on smaller screens for now
        return const ShipmentsDesktopPage();
      },
    );
  }
}
