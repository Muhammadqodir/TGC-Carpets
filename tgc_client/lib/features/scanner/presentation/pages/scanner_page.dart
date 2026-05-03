import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import '../../domain/entities/scanned_item_entity.dart';

// ── Scanner Configuration ─────────────────────────────────────────────────
const bool _useBarcodeMode = true; // Set to true for barcode, false for QR
const _detectionSpeed = DetectionSpeed.normal;

class ScannerPage extends StatelessWidget {
  const ScannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ScannerBloc>(),
      child: const _ScannerView(),
    );
  }
}

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: _detectionSpeed,
    formats: _useBarcodeMode
        ? [BarcodeFormat.code128, BarcodeFormat.ean13]
        : [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final code = barcode!.rawValue!;

    // Validate format on client side: PB{batchId} PBI{itemId}
    final regex = RegExp(r'^PB\{\d+\}\s+PBI\{\d+\}$');
    if (!regex.hasMatch(code)) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Noto\'g\'ri QR kod formati. Format: PB{123} PBI{456}'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    context.read<ScannerBloc>().add(ScannerCodeScanned(code));
  }

  void _reset() {
    setState(() => _isProcessing = false);
    context.read<ScannerBloc>().add(const ScannerResetRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(_useBarcodeMode ? 'Barcode Skanerlash' : 'QR Skanerlash'),
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
            strokeWidth: 2,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: BlocConsumer<ScannerBloc, ScannerState>(
        listener: (context, state) {
          if (state is ScannerError) {
            final messenger = ScaffoldMessenger.of(context);
            messenger.clearSnackBars();
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
            // Allow scanning again after error
            Future.delayed(const Duration(seconds: 2), _reset);
          }
        },
        builder: (context, state) {
          if (state is ScannerLoaded) {
            return _ResultView(item: state.item, onReset: _reset);
          }

          // Show scanner overlay
          return Stack(
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
              ),
              // Overlay with scanning guide
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: _useBarcodeMode ? 300 : 250,
                          height: _useBarcodeMode ? 100 : 250,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _useBarcodeMode
                              ? 'Barkodni markazga joylashtiring'
                              : 'QR kodni markazga joylashtiring',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (state is ScannerScanning)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final ScannedItemEntity item;
  final VoidCallback onReset;

  const _ResultView({required this.item, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: const Color(0xFFE8ECEF),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Product Image ──────────────────────────────────────────
              Card(
                clipBehavior: Clip.antiAlias,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: item.product.colorImage != null
                      ? CachedNetworkImage(
                          imageUrl: item.product.colorImage!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: const Color(0xFFF0F2F5),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (_, __, ___) => _PlaceholderImage(),
                        )
                      : _PlaceholderImage(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Product Info ───────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mahsulot ma\'lumotlari',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                          label: 'Mahsulot', value: item.product.name),
                      if (item.product.sizeLabel != null)
                        _InfoRow(
                            label: 'O\'lcham', value: item.product.sizeLabel!),
                      if (item.product.color != null)
                        _InfoRow(
                            label: 'Rang',
                            value: item.product.color!.toUpperCase()),
                      if (item.product.quality != null)
                        _InfoRow(
                            label: 'Sifat',
                            value: item.product.quality!.toUpperCase()),
                      if (item.product.type != null)
                        _InfoRow(
                            label: 'Turi',
                            value: item.product.type!.toUpperCase()),
                      if (item.product.sku != null)
                        _InfoRow(label: 'SKU', value: item.product.sku!),
                      if (item.product.barcode != null)
                        _InfoRow(
                            label: 'Barkod', value: item.product.barcode!),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Production Info ────────────────────────────────────────
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ishlab chiqarish ma\'lumotlari',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                          label: 'Batch ID',
                          value: '#${item.productionBatch.id}'),
                      if (item.productionBatch.batchTitle != null)
                        _InfoRow(
                            label: 'Batch nomi',
                            value: item.productionBatch.batchTitle!),
                      _InfoRow(
                          label: 'Status',
                          value: _statusLabel(item.productionBatch.status)),
                      _InfoRow(
                          label: 'Turi',
                          value: _typeLabel(item.productionBatch.type)),
                      if (item.productionBatch.machineName != null)
                        _InfoRow(
                            label: 'Mashina',
                            value: item.productionBatch.machineName!),
                      if (item.productionBatch.employeeName != null)
                        _InfoRow(
                            label: 'Ishchi',
                            value: item.productionBatch.employeeName!),
                      if (item.productionBatch.responsibleEmployeeName != null)
                        _InfoRow(
                            label: 'Mas\'ul ishchi',
                            value:
                                item.productionBatch.responsibleEmployeeName!),
                      if (item.productionBatch.completedDatetime != null)
                        _InfoRow(
                            label: 'Tugallangan',
                            value: _formatDate(
                                item.productionBatch.completedDatetime!)),
                      const Divider(height: 24),
                      _InfoRow(
                          label: 'Rejalashtirilgan',
                          value: '${item.item.plannedQuantity} dona'),
                      _InfoRow(
                          label: 'Ishlab chiqarilgan',
                          value: '${item.item.producedQuantity} dona'),
                      _InfoRow(
                          label: 'Defekt',
                          value: '${item.item.defectQuantity} dona'),
                      _InfoRow(
                          label: 'Omborga qabul qilingan',
                          value: '${item.item.warehouseReceivedQuantity} dona'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Destination Info ───────────────────────────────────────
              if (item.destination != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yo\'nalish',
                          style: textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (item.destination!.isForClient) ...[
                          _InfoRow(
                              label: 'Mijoz',
                              value: item.destination!.clientName ?? '—'),
                          _InfoRow(
                              label: 'Hudud',
                              value: item.destination!.region ?? '—'),
                          if (item.destination!.orderUuid != null)
                            _InfoRow(
                                label: 'Buyurtma',
                                value: item.destination!.orderUuid!),
                        ] else
                          _InfoRow(label: 'Yo\'nalish', value: 'Ombor'),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              // ── Scan Again Button ──────────────────────────────────────
              FilledButton.icon(
                onPressed: onReset,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedQrCode,
                  color: Colors.white,
                  strokeWidth: 2,
                ),
                label: const Text('Yana skanerlash'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'planned':
        return 'Rejalashtirilgan';
      case 'in_progress':
        return 'Jarayonda';
      case 'completed':
        return 'Tugallangan';
      case 'cancelled':
        return 'Bekor qilingan';
      default:
        return status;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'by_order':
        return 'Buyurtma bo\'yicha';
      case 'for_stock':
        return 'Ombor uchun';
      case 'mixed':
        return 'Aralash';
      default:
        return type;
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: const Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedPrayerRug01,
          size: 64,
          color: AppColors.textSecondary,
          strokeWidth: 1.5,
        ),
      ),
    );
  }
}
