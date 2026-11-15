import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../../core/utils/pdf_downloader.dart';
import '../../domain/entities/production_analytics_entity.dart';
import '../services/production_report_pdf_exporter.dart';

/// Saves the PDF and returns where it went (null = cancelled / shared).
typedef PdfSaver = Future<String?> Function(Uint8List bytes, String fileName);

/// App-bar button: the loaded report, for the period on screen, as a PDF.
/// Desktop gets a save-as dialog; a phone gets the share sheet, from which
/// it opens, prints or goes to Telegram.
class ProductionReportPdfButton extends StatefulWidget {
  final ProductionAnalyticsEntity data;
  final ProductionReportPdfExporter? exporter;
  final PdfSaver? saver;

  const ProductionReportPdfButton({super.key, required this.data, this.exporter, this.saver});

  @override
  State<ProductionReportPdfButton> createState() => _ProductionReportPdfButtonState();
}

class _ProductionReportPdfButtonState extends State<ProductionReportPdfButton> {
  bool _busy = false;

  static bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  static Future<String?> _defaultSave(Uint8List bytes, String fileName) async {
    if (_isDesktop) return downloadPdf(bytes, fileName);
    await Printing.sharePdf(bytes: bytes, filename: fileName);
    return null;
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await (widget.exporter ?? ProductionReportPdfExporter()).export(widget.data);
      final path = await (widget.saver ?? _defaultSave)(
        bytes,
        ProductionReportPdfExporter.fileName(widget.data),
      );
      if (path != null) {
        messenger.showSnackBar(SnackBar(
          content: Text('Saqlandi: $path'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('PDF yaratishda xatolik: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return IconButton(
      onPressed: _export,
      icon: const Icon(Icons.picture_as_pdf_outlined),
      tooltip: 'PDF yuklab olish',
    );
  }
}
