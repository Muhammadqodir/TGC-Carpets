import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/production_batch_entity.dart';
import '../bloc/production_batch_form_bloc.dart';
import 'desktop/production_batch_form_desktop_page.dart';
import 'mobile/production_batch_form_mobile_page.dart';

class ProductionBatchFormPage extends StatelessWidget {
  final ProductionBatchEntity? batch;

  const ProductionBatchFormPage({super.key, this.batch});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductionBatchFormBloc>(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
            return ProductionBatchFormDesktopPage(initialBatch: batch);
          }
          return ProductionBatchFormMobilePage(initialBatch: batch);
        },
      ),
    );
  }
}
