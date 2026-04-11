import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/production_batches_bloc.dart';
import '../bloc/production_batches_event.dart';
import 'desktop/production_batches_desktop_page.dart';
import 'mobile/production_batches_mobile_page.dart';

class ProductionBatchesPage extends StatelessWidget {
  const ProductionBatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductionBatchesBloc>()
        ..add(const ProductionBatchesLoadRequested()),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
            return const ProductionBatchesDesktopPage();
          }
          return const ProductionBatchesMobilePage();
        },
      ),
    );
  }
}
