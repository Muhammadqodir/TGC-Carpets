import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/production_batch_entity.dart';
import 'desktop/defect_document_form_desktop_page.dart';
import 'mobile/defect_document_form_mobile_page.dart';

class DefectDocumentFormPage extends StatelessWidget {
  final ProductionBatchEntity batch;

  const DefectDocumentFormPage({super.key, required this.batch});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return DefectDocumentFormDesktopPage(batch: batch);
        }
        return DefectDocumentFormMobilePage(batch: batch);
      },
    );
  }
}
