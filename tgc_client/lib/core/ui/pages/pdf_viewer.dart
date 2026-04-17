import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:printing/printing.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/pdf_downloader.dart';

class PdfViewerPage extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const PdfViewerPage({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  bool _isDesktop(BuildContext context) {
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            strokeWidth: 2,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: isDesktop ? 'Yuklab olish' : 'Ulashish / Chop etish',
            icon: HugeIcon(
              icon: isDesktop
                  ? HugeIcons.strokeRoundedDownload01
                  : HugeIcons.strokeRoundedShare01,
              strokeWidth: 2,
            ),
            onPressed: () async {
              final bytes = await _fetchBytes();
              if (isDesktop) {
                final messenger = ScaffoldMessenger.of(context);
                final path = await downloadPdf(bytes, '$title.pdf');
                if (path != null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Saqlandi: $path'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');
              }
            },
          ),
        ],
      ),
      body: PdfPreview(
        useActions: false,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: '$title.pdf',
        loadingWidget: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('PDF yuklanmoqda...'),
            ],
          ),
        ),
        onError: (context, error) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text("PDF ni ochib bo'lmadi"),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        build: (_) => _fetchBytes(),
      ),
    );
  }

  Future<Uint8List> _fetchBytes() async {
    final response = await sl<Dio>().get<List<int>>(
      pdfUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? []);
  }
}
