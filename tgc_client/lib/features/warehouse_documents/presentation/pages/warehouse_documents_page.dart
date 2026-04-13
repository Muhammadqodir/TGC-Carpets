import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/constants/app_constants.dart';

import '../../../../core/di/injection.dart';
import '../bloc/warehouse_docs_bloc.dart';
import '../bloc/warehouse_docs_event.dart';
import 'desktop/warehouse_documents_desktop_page.dart';
import 'mobile/warehouse_documents_mobile_page.dart';

/// Adaptive entry point: dispatches to [WarehouseDocumentsDesktopPage] or
/// [WarehouseDocumentsMobilePage] based on available width.
class WarehouseDocumentsPage extends StatelessWidget {
  const WarehouseDocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<WarehouseDocsBloc>()..add(const WarehouseDocsLoadRequested()),
      child: const _AdaptiveWarehouseView(),
    );
  }
}

class _AdaptiveWarehouseView extends StatelessWidget {
  const _AdaptiveWarehouseView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return const WarehouseDocumentsDesktopPage();
        }
        return const WarehouseDocumentsMobilePage();
      },
    );
  }
}
