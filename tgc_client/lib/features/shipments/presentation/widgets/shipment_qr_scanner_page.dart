import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/shipment_import_entities.dart';
import '../../domain/repositories/shipment_repository.dart';
import 'shipment_form_controller.dart';

/// Full-screen QR scanner for adding items to a shipment straight from the
/// production label printed on each carpet.
///
/// Pushed from [AddShipmentPage] once a client has been selected. Each
/// scanned code is resolved server-side (ShipmentImportController::scan) to
/// a shippable order item for [clientId], then added/incremented directly
/// on [controller] — the same [ShipmentFormController] the form page is
/// listening to, so rows show up as soon as this page is popped. The camera
/// stays open across multiple scans so a worker can pack a whole shipment
/// without leaving the scanner.
class ShipmentQrScannerPage extends StatefulWidget {
  final int clientId;
  final String clientName;
  final ShipmentFormController controller;

  const ShipmentQrScannerPage({
    super.key,
    required this.clientId,
    required this.clientName,
    required this.controller,
  });

  @override
  State<ShipmentQrScannerPage> createState() => _ShipmentQrScannerPageState();
}

enum _FeedbackKind { added, incremented, limitReached, error }

class _ScanFeedback {
  final _FeedbackKind kind;
  final String title;
  final String? subtitle;
  const _ScanFeedback(this.kind, this.title, [this.subtitle]);
}

class _ShipmentQrScannerPageState extends State<ShipmentQrScannerPage> {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: [BarcodeFormat.qrCode],
  );
  final ShipmentRepository _repo = sl<ShipmentRepository>();

  bool _busy = false;
  String? _lastCode;
  _ScanFeedback? _feedback;
  int _scannedCount = 0;

  @override
  void dispose() {
    _scannerCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty || code == _lastCode) return;

    _lastCode = code;
    _resolve(code);
  }

  Future<void> _resolve(String code) async {
    setState(() => _busy = true);

    try {
      final result = await _repo.getShipmentScanItem(
        code: code,
        clientId: widget.clientId,
      );
      if (!mounted) return;

      result.fold(
        (failure) => setState(() {
          _feedback = _ScanFeedback(_FeedbackKind.error, failure.message);
        }),
        _applyItem,
      );
    } finally {
      // Debounces the dozens of detections mobile_scanner fires per second
      // while a code sits in frame, while still letting the same label be
      // deliberately re-scanned (e.g. two identical carpets) after a pause.
      // Runs even on an unexpected error so scanning never gets stuck.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _lastCode = null;
        });
      });
    }
  }

  void _applyItem(ShipmentImportItemEntity item) {
    final result = widget.controller.addOrIncrementItem(item);
    final title = item.edgeCode != null
        ? '${item.productName} [${item.edgeCode}]'
        : item.productName;
    final subtitle = [
      if (item.colorName != null) item.colorName!.toUpperCase(),
      if (item.sizeLabel != null) item.sizeLabel!,
    ].join(' · ');

    setState(() {
      switch (result) {
        case ScanAddResult.added:
          _scannedCount++;
          _feedback = _ScanFeedback(_FeedbackKind.added, title, subtitle);
        case ScanAddResult.incremented:
          _scannedCount++;
          _feedback =
              _ScanFeedback(_FeedbackKind.incremented, title, subtitle);
        case ScanAddResult.limitReached:
          _feedback = _ScanFeedback(
            _FeedbackKind.limitReached,
            title,
            'Mavjud miqdorning barchasi qo\'shilgan',
          );
      }
    });

    if (result == ScanAddResult.added) {
      _fillLastPrice(item);
    }
  }

  /// Mirrors AddShipmentPage._importFromOrder's price fetch: a freshly added
  /// row starts with an empty price, filled in the background once the
  /// client's last price for this variant comes back.
  Future<void> _fillLastPrice(ShipmentImportItemEntity item) async {
    final result = await _repo.getLastPrice(
      variantId: item.variantId,
      clientId: widget.clientId,
    );
    if (!mounted) return;

    result.fold((_) {}, (price) {
      if (price == null) return;
      for (final row in widget.controller.items) {
        if (row.orderItemId == item.orderItemId && row.priceCtrl.text.isEmpty) {
          row.priceCtrl.text = price.toStringAsFixed(2);
        }
      }
      widget.controller.notifyChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
            strokeWidth: 2,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.clientName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Tayyor',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _scannerCtrl, onDetect: _onDetect),

          // Scan guide + counter
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.7),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Yorliqdagi QR kodni markazga joylashtiring',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            top: 12,
            left: 16,
            child: _CounterChip(count: _scannedCount),
          ),

          if (_busy && _feedback == null)
            const Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Feedback card for the last scan
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _feedback != null
                    ? _FeedbackCard(
                        key: ValueKey(_feedback.hashCode),
                        feedback: _feedback!,
                      )
                    : const SizedBox(key: ValueKey('empty'), height: 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  final int count;
  const _CounterChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.qr_code_scanner_rounded,
              size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'Skanerlandi: $count',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final _ScanFeedback feedback;
  const _FeedbackCard({super.key, required this.feedback});

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (feedback.kind) {
      _FeedbackKind.added => (AppColors.success, Icons.add_circle_rounded),
      _FeedbackKind.incremented => (
          AppColors.success,
          Icons.check_circle_rounded
        ),
      _FeedbackKind.limitReached => (
          AppColors.warning,
          Icons.info_rounded
        ),
      _FeedbackKind.error => (AppColors.error, Icons.error_rounded),
    };

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  feedback.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (feedback.subtitle != null && feedback.subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      feedback.subtitle!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
