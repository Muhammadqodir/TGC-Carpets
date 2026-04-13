import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../production/domain/entities/production_batch_item_entity.dart';
import '../../../../production/domain/usecases/get_production_batch_item_usecase.dart';

/// Result returned from [QrScannerScreen] after a successful scan + lookup.
class QrScanResult {
  final ProductionBatchItemEntity item;
  final int batchId;
  final String batchTitle;

  const QrScanResult({
    required this.item,
    required this.batchId,
    required this.batchTitle,
  });
}

/// Full-screen QR scanner that:
///   1. Reads a code in the format  `PB{batchId} PBI{itemId}`
///   2. Calls [GetProductionBatchItemUseCase] to fetch the item detail
///   3. Pops with [QrScanResult] on success, or shows an error snackbar
///      and re-activates the scanner so the user can retry.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  static Future<QrScanResult?> show(BuildContext context) =>
      Navigator.of(context).push<QrScanResult>(
        MaterialPageRoute(builder: (_) => const QrScannerScreen()),
      );

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Parses "PB{12} PBI{34}" → (batchId: 12, itemId: 34)
  // Returns null if the format doesn't match.
  ({int batchId, int itemId})? _parseQr(String raw) {
    final pbMatch = RegExp(r'PB\{(\d+)\}').firstMatch(raw);
    final pbiMatch = RegExp(r'PBI\{(\d+)\}').firstMatch(raw);
    if (pbMatch == null || pbiMatch == null) return null;
    final batchId = int.tryParse(pbMatch.group(1)!);
    final itemId = int.tryParse(pbiMatch.group(1)!);
    if (batchId == null || itemId == null) return null;
    return (batchId: batchId, itemId: itemId);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    final ids = _parseQr(raw);
    if (ids == null) {
      _showError("Noto'g'ri QR kod formati");
      return;
    }

    setState(() => _processing = true);
    await _controller.stop();

    final useCase = sl<GetProductionBatchItemUseCase>();
    final result = await useCase(ids.batchId, ids.itemId);

    if (!mounted) return;

    result.fold(
      (failure) {
        _showError(failure.toString());
        setState(() => _processing = false);
        _controller.start();
      },
      (item) {
        final batchTitle = 'PB#${ids.batchId}';
        Navigator.of(context).pop(
          QrScanResult(
            item: item,
            batchId: ids.batchId,
            batchTitle: batchTitle,
          ),
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('QR-kodni skanerlash'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, state, __) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                color: state.torchState == TorchState.on
                    ? Colors.yellow
                    : Colors.white,
              ),
            ),
            onPressed: _controller.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay with a scan-window cutout
          CustomPaint(
            size: Size.infinite,
            painter: _ScanOverlayPainter(),
          ),
          // Hint text
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "QR-kodni ramkaga joylashtiring",
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ),
          if (_processing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }
}

// Simple overlay painter that darkens everything except a centred square.
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const side = 240.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
        center: Offset(cx, cy), width: side, height: side);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = Colors.black54);

    // Corner accents
    const accentLen = 20.0;
    const strokeW = 3.0;
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final l = rect.left;
    final t = rect.top;
    final r = rect.right;
    final b = rect.bottom;

    // TL
    canvas.drawLine(Offset(l, t + accentLen), Offset(l, t), paint);
    canvas.drawLine(Offset(l, t), Offset(l + accentLen, t), paint);
    // TR
    canvas.drawLine(Offset(r - accentLen, t), Offset(r, t), paint);
    canvas.drawLine(Offset(r, t), Offset(r, t + accentLen), paint);
    // BL
    canvas.drawLine(Offset(l, b - accentLen), Offset(l, b), paint);
    canvas.drawLine(Offset(l, b), Offset(l + accentLen, b), paint);
    // BR
    canvas.drawLine(Offset(r - accentLen, b), Offset(r, b), paint);
    canvas.drawLine(Offset(r, b), Offset(r, b - accentLen), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
