import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/production_batch_form_bloc.dart';
import '../bloc/production_batch_form_event.dart';
import 'args/production_batch_detail_args.dart';
import 'desktop/production_batch_detail_desktop_page.dart';
import 'mobile/production_batch_detail_mobile_page.dart';

class ProductionBatchDetailPage extends StatelessWidget {
  final ProductionBatchDetailArgs args;

  const ProductionBatchDetailPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductionBatchFormBloc>()
        ..add(ProductionBatchLoadRequested(args.batch.id)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
            return ProductionBatchDetailDesktopPage(
                initialBatch: args.batch);
          }
          return ProductionBatchDetailMobilePage(
              initialBatch: args.batch);
        },
      ),
    );
  }
}
