import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/production_batch_entity.dart';
import '../bloc/production_batch_form_bloc.dart';
import '../widgets/production_batch_form_controller.dart';
import 'desktop/add_production_batch_desktop_page.dart';
import 'mobile/add_production_batch_mobile_page.dart';

/// Unified adaptive entrypoint for both add and edit production batch flows.
///
/// Pass [batch] to enter edit mode (pre-fills form, submits an update).
/// Omit [batch] (or pass null) to enter add mode (empty form, creates new).
class ProductionBatchFormPage extends StatefulWidget {
  const ProductionBatchFormPage({super.key, this.batch});

  /// When non-null the form operates in edit mode.
  final ProductionBatchEntity? batch;

  @override
  State<ProductionBatchFormPage> createState() =>
      _ProductionBatchFormPageState();
}

class _ProductionBatchFormPageState extends State<ProductionBatchFormPage> {
  late final ProductionBatchFormController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ProductionBatchFormController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductionBatchFormBloc>(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
            return AddProductionBatchDesktopPage(
              controller: _ctrl,
              initialBatch: widget.batch,
            );
          }
          return AddProductionBatchMobilePage(
            controller: _ctrl,
            initialBatch: widget.batch,
          );
        },
      ),
    );
  }
}
