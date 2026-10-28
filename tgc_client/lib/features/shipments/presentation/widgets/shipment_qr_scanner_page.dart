import 'dart:async';

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
import 'shipment_item_row.dart';

/// The label text as the server should see it, or null for nothing usable.
/// Printed labels hold plain ASCII like `P808 I5648`; a worn label or a camera
/// misread can wrap it in whitespace, a BOM or zero-width characters, none of
/// which the server's label patterns accept.
String? cleanScannedLabel(String? raw) {
  if (raw == null) return null;
  final code = raw
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F\u200B-\u200D\u2060\uFEFF]'), ' ')
      .trim();
  return code.isEmpty ? null : code;
}

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

/// What one successful scan did, handed back to the shipment form: since
/// October 2026 the scanner closes after every carpet it adds, so the worker
/// sees the real list — every order the carpet landed on, every warning —
/// before scanning the next one.
class ShipmentScanOutcome {
  final ShipmentItemRow row;
  final bool incremented;
  final String title;

  const ShipmentScanOutcome({
    required this.row,
    required this.incremented,
    required this.title,
  });
}

enum _FeedbackKind { added, incremented, limitReached, error }

/// The outcome of one scan, as shown on the full-screen result step.
class _ScanFeedback {
  final _FeedbackKind kind;

  /// What happened, in two or three words ("Qo'shildi", "Yorliq topilmadi").
  final String headline;

  /// The carpet the scan resolved to. Null on an error, where there is none.
  final String? title;

  /// Colour · size for a resolved carpet, the server's own sentence on an
  /// error.
  final String? subtitle;

  /// Quantity now standing on the shipment row this scan touched, so the
  /// worker can check it against the pile without leaving the scanner.
  final int? quantity;

  const _ScanFeedback(
    this.kind, {
    required this.headline,
    this.title,
    this.subtitle,
    this.quantity,
  });
}

class _ShipmentQrScannerPageState extends State<ShipmentQrScannerPage> {
  final MobileScannerController _scannerCtrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: [BarcodeFormat.qrCode],
  );
  final ShipmentRepository _repo = sl<ShipmentRepository>();

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
  /// This is the only feedback that is honest about timing: it says "the
  /// camera has your label", which is what the worker is waiting for while
  /// aiming. Whether the carpet is shippable comes later, on screen.
  void _signalCapture() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  /// Extra alert for an outcome the worker has to act on. The capture click
  /// already fired, so this exists only to separate "read, and rejected" from
  /// "read, and fine" for someone who has looked away at the pile: two heavy
  /// beats plus the system alert, unmistakable through a glove.
  void _signalRejected() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted) HapticFeedback.heavyImpact();
    });
    SystemSound.play(SystemSoundType.alert);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_resolving || _sheetOpen || _feedback != null) return;
    final code = cleanScannedLabel(capture.barcodes.firstOrNull?.rawValue);
    if (code == null || code == _lastCode) return;

    // A different label ends any cooldown left over from the previous scan.
    _cooldown?.cancel();
    _lastCode = code;
    _signalCapture();
    _resolve(code);
  }

  Future<void> _resolve(String code) async {
    setState(() => _resolving = true);

    try {
      final result = await _repo.getShipmentScanItem(
        code: code,
        clientId: widget.clientId,
        inForm: widget.controller.quantitiesByOrderItem,
      );
      if (!mounted) return;

      result.fold(
        (failure) {
          _showResult(_ScanFeedback(
            _FeedbackKind.error,
            headline: _errorTitle(failure),
            subtitle: failure.message,
          ));
        },
        (item) {
          // Two things make a scan a decision rather than a result, and
          // either can be true on its own: this client has no order line for
          // the carpet (one gets invented for them), and the carpet was
          // produced for somebody else (it stops counting as ready for them
          // the moment it leaves). A plain carpet off this client's own order
          // goes straight in, which is the normal case on the floor.
          if (item.isOnClientOrder && item.producedForClient == null) {
            _applyItem(item);
          } else {
            _confirmScannedItem(item);
          }
        },
      );
    } catch (e) {
      // Anything the repository did not turn into a Failure. Before this, an
      // unexpected error showed no result at all — and since only dismissing
      // a result releases [_lastCode], the scanner then silently ignored that
      // label until a different one was scanned: a carpet that "won't scan".
      if (mounted) {
        _showResult(_ScanFeedback(
          _FeedbackKind.error,
          headline: 'Skanerlashda xatolik',
          subtitle: '$e',
        ));
      }
    } finally {
      // Clears even on an unexpected error, so the spinner can never strand
      // the scanner. Scanning stays blocked while the result screen or the
      // sheet is up; both hand control back through _resume().
      if (mounted) setState(() => _resolving = false);
    }
  }

  /// Shows the outcome full-screen and leaves it there. Nothing auto-dismisses:
  /// the worker's hands are on a carpet, and a card that fades on its own is
  /// one they will miss.
  void _showResult(_ScanFeedback feedback) {
    if (feedback.kind == _FeedbackKind.error ||
        feedback.kind == _FeedbackKind.limitReached) {
      _signalRejected();
    }
    setState(() => _feedback = feedback);
  }

  /// Back to the camera, from the result screen or a cancelled sheet.
  void _resume() {
    setState(() => _feedback = null);

    _cooldown?.cancel();
    _cooldown = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _lastCode = null;
    });
  }

  /// A short headline for the result screen, with the server's own sentence
  /// kept underneath it. Before this, a worker holding a carpet saw only a
  /// bare backend string and could not tell a dead phone signal from a label
  /// this client has no order for.
  String _errorTitle(Failure failure) {
    if (failure is NetworkFailure) return 'Internet aloqasi yo\'q';
    if (failure is UnauthorizedFailure) return 'Sessiya tugadi, qayta kiring';

    if (failure is ServerFailure) {
      return switch (failure.statusCode) {
        401 => 'Sessiya tugadi, qayta kiring',
        403 => 'Ruxsat yo\'q',
        404 => 'Yorliq topilmadi',
        422 => 'Ma\'lumot noto\'g\'ri',
        final int code when code >= 500 => 'Serverda xatolik',
        _ => 'Skanerlashda xatolik',
      };
    }

    return 'Skanerlashda xatolik';
  }

  /// Two gates before a carpet that is not simply this client's own is added.
  ///
  /// The first sheet explains what is true about this particular carpet — it
  /// was made for someone else, this client never ordered it, it was never
  /// booked into the warehouse — because none of that is visible from the
  /// shipment form. The second is a plain yes/no naming the one consequence
  /// that is hard to undo: another client's ready count drops, or stock goes
  /// out. A worker scanning fifty carpets moves fast, and the sheet alone was
  /// one tap away from being dismissed on autopilot.
  Future<void> _confirmScannedItem(ShipmentImportItemEntity item) async {
    // Neither accepted nor rejected — a lighter tap that says "look at me",
    // since this needs a decision before anything is added.
    HapticFeedback.selectionClick();
    setState(() => _sheetOpen = true);

    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _ScannedItemSheet(
        item: item,
        clientName: widget.clientName,
      ),
    );

    if (!mounted) return;

    final confirmed = proceed == true && await _confirmFinalAdd(item);
    if (!mounted) return;

    setState(() => _sheetOpen = false);

    if (confirmed) {
      _applyItem(item);
    } else {
      // Declined: no result screen to dismiss, so the camera is handed back
      // here — with the same cooldown, since it is still on that label.
      _resume();
    }
  }

  /// The second gate: one sentence, one question, two buttons.
  Future<bool> _confirmFinalAdd(ShipmentImportItemEntity item) async {
    final producedFor = item.producedForClient;

    final consequence = producedFor != null
        ? '"$producedFor" mijozining tayyor mahsuloti 1 taga kamayadi va bu '
            'gilam "${widget.clientName}" yuk xatiga qo\'shiladi. '
            'Ularning buyurtmasi qayta ishlab chiqarishga qaytadi.'
        : item.isBeyondOrder
            ? 'Bu gilam buyurtmadan ortiqcha bo\'lib "${widget.clientName}" '
                'yuk xatiga qo\'shiladi. Yuk xati saqlanganda unga yangi '
                'buyurtma qatori ochiladi.'
            : 'Bu gilam ombordan chiqariladi va "${widget.clientName}" yuk '
                'xatiga qo\'shiladi.';

    final answer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Rostdan ham qo\'shilsinmi?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          consequence,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Yo\'q',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: producedFor != null
                  ? AppColors.warning
                  : AppColors.success,
            ),
            child: const Text(
              'Ha, qo\'shilsin',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    return answer == true;
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

    if (result != ScanAddResult.limitReached) _scannedCount++;

    // Added or counted up: back to the list, which shows what this did to
    // the shipment far better than a card here could. Only a refusal stays
    // on screen, because there is nothing new on the list to look at.
    final row = _rowFor(item);
    if (result != ScanAddResult.limitReached && row != null) {
      Navigator.of(context).pop(ShipmentScanOutcome(
        row: row,
        incremented: result == ScanAddResult.incremented,
        title: [title, if (subtitle.isNotEmpty) subtitle].join(' · '),
      ));
      return;
    }

    _showResult(switch (result) {
      ScanAddResult.added => _ScanFeedback(
          _FeedbackKind.added,
          headline: 'Qo\'shildi',
          title: title,
          subtitle: subtitle,
          quantity: _rowQuantityFor(item),
        ),
      ScanAddResult.incremented => _ScanFeedback(
          _FeedbackKind.incremented,
          headline: 'Miqdor oshirildi',
          title: title,
          subtitle: subtitle,
          quantity: _rowQuantityFor(item),
        ),
      ScanAddResult.limitReached => _ScanFeedback(
          _FeedbackKind.limitReached,
          headline: 'Chegaraga yetdi',
          title: title,
          subtitle: 'Buyurtma bo\'yicha mavjud ${item.availableQuantity} '
              'dona allaqachon qo\'shilgan.',
          quantity: _rowQuantityFor(item),
        ),
    });
  }

  /// The form row [item] belongs to, or null before it has one.
  ///
  /// Off-order rows all carry a null orderItemId, so matching those on it
  /// would return whichever came first; they are identified by variant
  /// instead — the same rule [ShipmentFormController.addOrIncrementItem] uses.
  ShipmentItemRow? _rowFor(ShipmentImportItemEntity item) {
    for (final row in widget.controller.items) {
      final isTheRow = item.isOnClientOrder
          ? row.orderItemId == item.orderItemId
          : row.orderItemId == null && row.variantId == item.variantId;
      if (isTheRow) return row;
    }
    return null;
  }

  int? _rowQuantityFor(ShipmentImportItemEntity item) =>
      _rowFor(item)?.parsedQuantity;

  // No last-price fetch on scan any more: this form carries no prices, so it
  // was a round trip per carpet that nothing displayed. Pricing is its own
  // feature now.

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
              'QR kod o\'qildi',
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
                      if (feedback.title != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          feedback.title!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ],
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
                      if (feedback.quantity != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            'Yuk xatida: ${feedback.quantity} dona',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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

/// First gate for a scanned carpet that is not simply this client's own:
/// what is true about it, spelled out, before anything is added.
///
/// Covers two situations that can occur together or apart — the carpet was
/// produced against another client's order, and this client has no open order
/// line for it — because the shipment form shows neither, and the worker is
/// the only one who can see the physical carpet.
class _ScannedItemSheet extends StatelessWidget {
  final ShipmentImportItemEntity item;
  final String clientName;

  const _ScannedItemSheet({required this.item, required this.clientName});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (item.colorName != null) item.colorName!.toUpperCase(),
      if (item.sizeLabel != null) item.sizeLabel!,
      if (item.qualityName != null) item.qualityName!,
    ].join(' · ');

    final producedFor = item.producedForClient;
    final title = producedFor != null
        ? 'Boshqa mijozning mahsuloti'
        : item.isBeyondOrder
            ? 'Buyurtmadan ortiqcha mahsulot'
            : 'Buyurtmada yo\'q mahsulot';

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
                    title,
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

            // The carpet's own story first: whose it was made for is the
            // fact that decides everything else on this sheet.
            if (producedFor != null)
              _SheetNote(
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
                text: 'Bu mahsulot "$producedFor" mijozining buyurtmasi uchun '
                    'ishlab chiqarilgan. Qo\'shsangiz, uning tayyor soni '
                    '1 taga kamayadi va buyurtmasi qayta ishlab chiqarishga '
                    'qaytadi.',
              )
            else
              _SheetNote(
                icon: Icons.inventory_2_outlined,
                color: Colors.white70,
                // Beyond the order, the carpet may well be this client's own
                // production — so that case states only the stock, not whose
                // order it is attached to.
                text: switch ((item.isBeyondOrder, item.stockQuantity > 0)) {
                  (true, true) => 'Ombordagi zaxiradan chiqariladi (hozir '
                      'omborda: ${item.stockQuantity} dona).',
                  (true, false) => 'Omborda kirim qilinmagan. Yuk xati '
                      'saqlanganda avtomatik kirim qilinib, chiqim qilinadi.',
                  (false, true) => 'Bu mahsulot hech bir mijoz buyurtmasiga '
                      'biriktirilmagan — ombordagi zaxiradan chiqariladi '
                      '(hozir omborda: ${item.stockQuantity} dona).',
                  (false, false) => 'Bu mahsulot hech bir mijoz buyurtmasiga '
                      'biriktirilmagan va omborda kirim qilinmagan. Yuk xati '
                      'saqlanganda avtomatik kirim qilinib, chiqim qilinadi.',
                },
              ),

            // Then what it costs this client's paperwork.
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _SheetNote(
                icon: Icons.info_outline_rounded,
                color: Colors.white70,
                text: item.isOnClientOrder
                    ? '"$clientName" mijozining ochiq buyurtma qatoriga '
                        'yoziladi.'
                    : item.isBeyondOrder
                        ? '"$clientName" mijozining bu mahsulot bo\'yicha ochiq '
                            'buyurtmasi to\'liq yuk xatiga qo\'shilgan. '
                            'Qo\'shsangiz, yuk xati saqlanganda unga yangi '
                            'buyurtma qatori ochiladi.'
                        : '"$clientName" mijozining ochiq buyurtmasida bu '
                            'mahsulot yo\'q. Qo\'shsangiz, yuk xati saqlanganda '
                            'unga yangi buyurtma qatori ochiladi.',
              ),
            ),
            if (producedFor != null && item.stockQuantity <= 0)
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
                      'Davom etish',
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
