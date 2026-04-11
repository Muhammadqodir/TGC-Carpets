import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/production_batch_entity.dart';
import 'desktop/production_batch_detail_desktop_page.dart';
import 'mobile/production_batch_detail_mobile_page.dart';

class ProductionBatchDetailPage extends StatelessWidget {
  final ProductionBatchEntity batch;

  const ProductionBatchDetailPage({super.key, required this.batch});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return ProductionBatchDetailDesktopPage(batch: batch);
        }
        return ProductionBatchDetailMobilePage(batch: batch);
      },
    );
  }
}
