import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../data/datasources/production_batch_remote_datasource.dart';
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
  ProductionBatchEntity? _fullBatch;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = ProductionBatchFormController();
    if (widget.batch != null) {
      _fetchFullBatch(widget.batch!);
    }
  }

  Future<void> _fetchFullBatch(ProductionBatchEntity partial) async {
    setState(() => _loading = true);
    try {
      final full = await sl<ProductionBatchRemoteDataSource>()
          .getProductionBatch(partial.id);
      if (!mounted) return;
      _ctrl.loadFromBatch(full);
      setState(() {
        _fullBatch = full;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // In edit mode, show a spinner until the full batch (with items) is loaded
    if (widget.batch != null && _loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tahrirlash...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final effectiveBatch = _fullBatch ?? widget.batch;

    return BlocProvider(
      create: (_) => sl<ProductionBatchFormBloc>(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
            return AddProductionBatchDesktopPage(
              controller: _ctrl,
              initialBatch: effectiveBatch,
            );
          }
          return AddProductionBatchMobilePage(
            controller: _ctrl,
            initialBatch: effectiveBatch,
          );
        },
      ),
    );
  }
}
