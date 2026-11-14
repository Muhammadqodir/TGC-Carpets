import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../labeling/domain/carpet_number.dart';
import '../../domain/entities/shipment_import_entities.dart';
import '../../domain/repositories/shipment_repository.dart';
import 'shipment_form_controller.dart';
import 'shipment_scan_flow.dart';

export 'shipment_scan_flow.dart' show cleanScannedLabel, ShipmentScanOutcome;

/// Full-screen camera scanner for adding items to a shipment straight from the
/// production label printed on each carpet.
///
/// Pushed from [AddShipmentPage] once a client has been selected. Each
/// scanned code goes through [ShipmentScanFlow] — resolved server-side
/// (ShipmentImportController::scan) to a shippable order item for
/// [clientId], then added to [controller], the same [ShipmentFormController]
/// the form page is listening to. A Zebra PDA skips this page: its trigger
/// button feeds the same flow straight from the list.
///
/// One scan runs as three stages, each with its own full-screen state, so a
/// worker holding a carpet at arm's length can never miss where the scan got
/// to: the code is read (sound + vibration, instantly), the server resolves it
/// (blocking spinner), and the outcome is shown (result screen, dismissed by
/// hand). Nothing is left to a small indicator in a corner.
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

/// The outcome of one scan, as shown on the full-screen result step.
class _ScanFeedback {
  final _FeedbackKind kind;

  /// What happened, in two or three words ("Qo'shildi", "Yorliq topilmadi").
  final String headline;

  /// The full sentence under the headline.
  final String? subtitle;

  const _ScanFeedback(
    this.kind, {
    required this.headline,
    this.subtitle,
  });
}

class _ShipmentQrScannerPageState extends State<ShipmentQrScannerPage> {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    // Data Matrix on new labels, QR on the ones already on carpets, and the
    // Code 128 carpet number (21…) printed since November 2026.
    formats: [
      BarcodeFormat.dataMatrix,
      BarcodeFormat.qrCode,
      BarcodeFormat.code128,
    ],
  );
  late final ShipmentScanFlow _flow = ShipmentScanFlow(
    repo: sl<ShipmentRepository>(),
    controller: widget.controller,
    clientId: widget.clientId,
    clientName: widget.clientName,
  );

  /// True from the moment a code is read until the server answers. Covers the
  /// screen: the round trip runs over factory wifi and can take seconds, and
  /// a worker who cannot tell "still working" from "nothing happened" scans
  /// the same carpet again.
  bool _resolving = false;

  /// True while the "add anyway" sheet is up, so the camera behind it cannot
  /// stack a second sheet on top.
  bool _sheetOpen = false;

  String? _lastCode;

  /// Releases [_lastCode] a beat after the result screen is dismissed. The
  /// phone is still pointed at the label just handled, so an immediate
  /// release would re-scan it before the worker can move to the next carpet;
  /// a label shared by two identical carpets is still re-scannable once the
  /// timer fires.
  Timer? _cooldown;

  /// Non-null = the result screen is up and scanning is paused until the
  /// worker dismisses it.
  _ScanFeedback? _feedback;

  int _scannedCount = 0;

  @override
  void dispose() {
    _cooldown?.cancel();
    _scannerCtrl.dispose();
    super.dispose();
  }

  /// Fired the instant a code is read, before the server is asked anything.
  void _signalCapture() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  /// Extra alert for an outcome the worker has to act on: two heavy beats
  /// plus the system alert, unmistakable through a glove.
  void _signalRejected() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
    SystemSound.play(SystemSoundType.alert);
  }

  /// The code worth sending from one camera frame. A label holds up to three
  /// codes; the carpet number names this very carpet, the square code names
  /// its production line, and the product barcode only the product.
  String? _bestCode(BarcodeCapture capture) {
    final codes = [
      for (final b in capture.barcodes)
        if (cleanScannedLabel(b.rawValue) case final String c) c,
    ];
    if (codes.isEmpty) return null;
    return codes.firstWhere(isCarpetNumber,
        orElse: () => codes.firstWhere(
              (c) => !RegExp(r'^\d{13}$').hasMatch(c),
              orElse: () => codes.first,
            ));
  }

  void _onDetect(BarcodeCapture capture) {
    if (_resolving || _sheetOpen || _feedback != null) return;
    final code = _bestCode(capture);
    if (code == null || code == _lastCode) return;

    // A different label ends any cooldown left over from the previous scan.
    _cooldown?.cancel();
    _lastCode = code;
    _signalCapture();
    _handle(code);
  }

  Future<void> _handle(String code) async {
    final refused = _flow.precheck(code);
    if (refused != null) {
      _showRejection(refused);
      return;
    }

    setState(() => _resolving = true);
    final (item, rejection) = await _flow.resolve(code);
    if (!mounted) return;
    // Clears before any sheet, so the spinner can never strand the scanner.
    setState(() => _resolving = false);

    if (rejection != null || item == null) {
      _showRejection(rejection ??
          const ShipmentScanRejection('Skanerlashda xatolik'));
      return;
    }

    await _confirmAndApply(item, code);
  }

  Future<void> _confirmAndApply(
      ShipmentImportItemEntity item, String code) async {
    setState(() => _sheetOpen = true);
    final confirmed = await _flow.confirm(context, item);
    if (!mounted) return;
    setState(() => _sheetOpen = false);

    if (!confirmed) {
      // Declined: no result screen to dismiss, so the camera is handed back
      // here — with the same cooldown, since it is still on that label.
      _resume();
      return;
    }

    final outcome = _flow.apply(item, code);
    if (outcome == null) {
      _showRejection(const ShipmentScanRejection(
        'Skanerlashda xatolik',
        message: 'Mahsulot ro\'yxatga qo\'shilmadi. Qayta skanerlang.',
      ));
      return;
    }
    _scannedCount++;
    // Straight back to the list, which shows what this did to the shipment
    // far better than a card here could. Only refusals stay on this screen.
    Navigator.of(context).pop(outcome);
  }

  /// Shows a refusal full-screen and leaves it there. Nothing auto-dismisses:
  /// the worker's hands are on a carpet, and a card that fades on its own is
  /// one they will miss.
  void _showRejection(ShipmentScanRejection rejection) {
    _signalRejected();
    setState(() => _feedback = _ScanFeedback(
          rejection.isWarning ? _FeedbackKind.limitReached : _FeedbackKind.error,
          headline: rejection.headline,
          subtitle: rejection.message,
        ));
  }

  /// Back to the camera, from the result screen or a cancelled sheet.
  void _resume() {
    setState(() => _feedback = null);

    _cooldown?.cancel();
    _cooldown = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _lastCode = null;
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
                    'Yorliqdagi kodni markazga joylashtiring',
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

          // The two blocking steps of a scan, over the whole camera frame.
          // Both are opaque: at arm's length nothing smaller than the full
          // screen is read reliably, and covering the viewfinder is itself
          // the signal that the scanner is not listening right now.
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: switch ((_resolving, _feedback)) {
                (true, _) => const _ResolvingOverlay(key: ValueKey('busy')),
                (false, final _ScanFeedback f) => _ScanResultOverlay(
                    key: const ValueKey('result'),
                    feedback: f,
                    scannedCount: _scannedCount,
                    onScanMore: _resume,
                    onFinish: () => Navigator.of(context).pop(),
                  ),
                _ => const SizedBox.shrink(key: ValueKey('idle')),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Covers the frame while the server resolves a scanned label. The click and
/// the buzz already told the worker the code was read; this says the phone is
/// still working on it, which over factory wifi can be several seconds.
class _ResolvingOverlay extends StatelessWidget {
  const _ResolvingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.88),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 5,
              ),
            ),
            SizedBox(height: 28),
            Text(
              'Kod o\'qildi',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tekshirilmoqda…',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// The outcome of the last scan, over the whole frame and staying put until
/// the worker taps. Scanning is paused behind it: the deliberate tap is what
/// stops a phone still aimed at the carpet from adding it twice, and it gives
/// the worker a moment to check the running quantity against the pile.
class _ScanResultOverlay extends StatelessWidget {
  final _ScanFeedback feedback;
  final int scannedCount;
  final VoidCallback onScanMore;
  final VoidCallback onFinish;

  const _ScanResultOverlay({
    super.key,
    required this.feedback,
    required this.scannedCount,
    required this.onScanMore,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (feedback.kind) {
      _FeedbackKind.added => (AppColors.success, Icons.add_circle_rounded),
      _FeedbackKind.incremented => (
          AppColors.success,
          Icons.check_circle_rounded
        ),
      _FeedbackKind.limitReached => (AppColors.warning, Icons.info_rounded),
      _FeedbackKind.error => (AppColors.error, Icons.error_rounded),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        // Tinted black rather than the flat colour: the icon and headline
        // still have to read as text on top of it.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(color.withValues(alpha: 0.32), Colors.black),
            Colors.black.withValues(alpha: 0.97),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 24),
                      // Pops in rather than appearing, so a worker glancing
                      // back at the phone can tell a fresh result from the
                      // one they already dealt with.
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.6, end: 1),
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.withValues(alpha: 0.6),
                              width: 3,
                            ),
                          ),
                          child: Icon(icon, color: color, size: 60),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        feedback.headline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      if (feedback.subtitle != null &&
                          feedback.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          feedback.subtitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Jami skanerlandi: $scannedCount',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Thumb-sized and at the bottom of the screen: this is tapped
              // once per carpet, often one-handed with the other hand on the
              // pile.
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: onScanMore,
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
                  label: const Text(
                    'Yana skanerlash',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: onFinish,
                  child: const Text(
                    'Tayyor, yuk xatiga qaytish',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
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
