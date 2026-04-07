import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:printing/printing.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';

class WarehousePdfViewerPage extends StatelessWidget {
  final String pdfUrl;
  final String title;

  const WarehousePdfViewerPage({
    super.key,
    required this.pdfUrl,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
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
            tooltip: 'Ulashish / Chop etish',
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedShare01,
              strokeWidth: 2,
            ),
            onPressed: () async {
              final bytes = await _fetchBytes();
              await Printing.sharePdf(bytes: bytes, filename: '$title.pdf');
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
