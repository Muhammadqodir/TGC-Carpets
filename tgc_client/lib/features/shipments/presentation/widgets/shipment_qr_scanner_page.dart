import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/error/failures.dart';
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

class _ShipmentQrScannerPageState extends State<ShipmentQrScannerPage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: [BarcodeFormat.qrCode],
  );
  final ShipmentRepository _repo = sl<ShipmentRepository>();

  bool _busy = false;
  /// True while the "add anyway" sheet is up, so the camera behind it cannot
  /// stack a second sheet on top after the debounce expires.
  bool _sheetOpen = false;
  String? _lastCode;
  _ScanFeedback? _feedback;
  int _scannedCount = 0;

  /// Drives the full-screen colour wash after each scan. A worker holds the
  /// phone at arm's length over a carpet and cannot read a card at that
  /// distance — the colour is what they actually register, so it covers the
  /// whole frame and fades over ~1.2s rather than blinking.
  late final AnimationController _flashCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  Color _flashColor = AppColors.success;

  @override
  void dispose() {
    _flashCtrl.dispose();
    _scannerCtrl.dispose();
    super.dispose();
  }

  /// Colour wash + haptic + click, fired together so the scan lands whichever
  /// sense is free: eyes on the carpet, phone in a gloved hand, or a noisy
  /// floor. Distinct patterns per outcome — one short tap for a good scan,
  /// a heavier double for a rejection — so it is legible without looking.
  void _signal(_FeedbackKind kind) {
    final color = switch (kind) {
      _FeedbackKind.added || _FeedbackKind.incremented => AppColors.success,
      _FeedbackKind.limitReached => AppColors.warning,
      _FeedbackKind.error => AppColors.error,
    };

    setState(() => _flashColor = color);
    _flashCtrl.forward(from: 0);

    switch (kind) {
      case _FeedbackKind.added:
      case _FeedbackKind.incremented:
        HapticFeedback.mediumImpact();
        SystemSound.play(SystemSoundType.click);
      case _FeedbackKind.limitReached:
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      case _FeedbackKind.error:
        // Two beats: unmistakably not the "accepted" pattern, even in a
        // pocket or through a glove.
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 160), () {
          if (mounted) HapticFeedback.heavyImpact();
        });
        SystemSound.play(SystemSoundType.alert);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy || _sheetOpen) return;
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
        (failure) {
          _signal(_FeedbackKind.error);
          setState(() {
            _feedback = _ScanFeedback(
              _FeedbackKind.error,
              _errorTitle(failure),
              failure.message,
            );
          });
        },
        (item) {
          // A carpet this client has no order line for is a decision, not a
          // result: the worker confirms it in a sheet before anything is
          // added, because adding it will invent an order line for them.
          if (item.isOnClientOrder) {
            _applyItem(item);
          } else {
            _confirmAddAnyway(item);
          }
        },
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

  /// A short headline for the feedback card, with the server's own sentence
  /// kept underneath it. Before this, a worker holding a carpet saw only a
  /// bare backend string and could not tell a dead phone signal from a label
  /// this client has no order for.
  String _errorTitle(Failure failure) {
    if (failure is NetworkFailure) return 'Internet aloqasi yo\'q';
    if (failure is UnauthorizedFailure) return 'Sessiya tugadi, qayta kiring';

    if (failure is ServerFailure) {
      return switch (failure.statusCode) {
        404 => 'Yorliq topilmadi',
        422 => 'Ma\'lumot noto\'g\'ri',
        final int code when code >= 500 => 'Serverda xatolik',
        _ => 'Skanerlashda xatolik',
      };
    }

    return 'Skanerlashda xatolik';
  }

  /// Confirmation before inventing demand: adding a carpet the client never
  /// ordered creates an order line for them when the shipment is saved, and
  /// when the carpet was produced against someone else's order that other
  /// order stays open and still owed. Both are spelled out in the sheet.
  Future<void> _confirmAddAnyway(ShipmentImportItemEntity item) async {
    // Neither accepted nor rejected — a lighter tap that says "look at me",
    // since the sheet needs a decision before anything is added.
    HapticFeedback.selectionClick();
    setState(() => _sheetOpen = true);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _AddAnywaySheet(
        item: item,
        clientName: widget.clientName,
      ),
    );

    if (!mounted) return;
    setState(() => _sheetOpen = false);

    if (confirmed == true) {
      _applyItem(item);
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

    final kind = switch (result) {
      ScanAddResult.added => _FeedbackKind.added,
      ScanAddResult.incremented => _FeedbackKind.incremented,
      ScanAddResult.limitReached => _FeedbackKind.limitReached,
    };
    _signal(kind);

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
        if (row.priceCtrl.text.isNotEmpty) continue;

        // Off-order rows all have a null orderItemId, so comparing those
        // would price whichever one came first. They are identified by
        // variant instead — the same rule addOrIncrementItem uses.
        final isTheRow = item.isOnClientOrder
            ? row.orderItemId == item.orderItemId
            : row.orderItemId == null && row.variantId == item.variantId;

        if (isTheRow) {
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

          // Result wash. Strongest at the edges and clear in the middle, so
          // it reads instantly at arm's length without hiding the carpet the
          // worker is aiming at. IgnorePointer because it covers the frame.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _flashCtrl,
                builder: (context, _) {
                  if (_flashCtrl.value == 0) return const SizedBox.shrink();

                  // Fades out over the tail of the animation rather than
                  // linearly, so the colour is unmistakable on arrival and
                  // still gone within ~1.2s.
                  final opacity = (1 - _flashCtrl.value) * 0.55;

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [
                          _flashColor.withValues(alpha: opacity * 0.25),
                          _flashColor.withValues(alpha: opacity),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

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

/// Confirmation sheet for a scanned carpet the selected client has no open
/// order line for. Deliberately spells out the two consequences the worker
/// cannot see from the shipment form: an order line will be created for this
/// client, and if the carpet was produced for someone else, that order stays
/// unfilled.
class _AddAnywaySheet extends StatelessWidget {
  final ShipmentImportItemEntity item;
  final String clientName;

  const _AddAnywaySheet({required this.item, required this.clientName});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (item.colorName != null) item.colorName!.toUpperCase(),
      if (item.sizeLabel != null) item.sizeLabel!,
      if (item.qualityName != null) item.qualityName!,
    ].join(' · ');

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.help_outline_rounded,
                    color: AppColors.warning, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buyurtmada yo\'q mahsulot',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              item.edgeCode != null
                  ? '${item.productName} [${item.edgeCode}]'
                  : item.productName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            const SizedBox(height: 16),

            _SheetNote(
              icon: Icons.info_outline_rounded,
              color: Colors.white70,
              text: '"$clientName" mijozining ochiq buyurtmasida bu mahsulot '
                  'yo\'q. Qo\'shsangiz, yuk xati saqlanganda unga yangi '
                  'buyurtma qatori ochiladi.',
            ),
            if (item.producedForClient != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _SheetNote(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warning,
                  text: 'Bu mahsulot "${item.producedForClient}" buyurtmasi '
                      'uchun ishlab chiqarilgan. Uning buyurtmasi yopilmaydi '
                      've hali ham kutilib qoladi.',
                ),
              ),
            if (item.stockQuantity <= 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _SheetNote(
                  icon: Icons.inventory_2_outlined,
                  color: Colors.white70,
                  text: 'Omborda kirim qilinmagan. Yuk xati saqlanganda '
                      'avtomatik kirim qilinadi.',
                ),
              ),
            const SizedBox(height: 22),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Bekor qilish',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Baribir qo\'shish',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetNote extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _SheetNote({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 13, height: 1.35),
          ),
        ),
      ],
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
                        height: 1.3,
                      ),
                      // A server error can now be several validation lines at
                      // once, so the card grows to fit them rather than
                      // hiding the one that mattered behind an ellipsis. The
                      // product-name subtitle of a normal scan is one short
                      // line, so nothing else changes shape.
                      maxLines: 8,
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
