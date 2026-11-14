import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../labeling/domain/carpet_number.dart';
import '../../../labeling/domain/product_barcode.dart';
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
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F​-‍⁠﻿]'), ' ')
      .trim();
  return code.isEmpty ? null : code;
}

/// What one successful scan did, handed back to the shipment form so it can
/// point at the row and say what happened.
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

/// A scan that put nothing on the shipment, and why.
class ShipmentScanRejection {
  /// Two or three words ("Yorliq topilmadi", "Allaqachon qo'shilgan").
  final String headline;

  /// The full sentence underneath, often the server's own.
  final String? message;

  /// A refusal the worker caused and can shrug off (same carpet twice, wrong
  /// code on the label), as opposed to an error.
  final bool isWarning;

  const ShipmentScanRejection(
    this.headline, {
    this.message,
    this.isWarning = false,
  });
}

/// One scan of a carpet's label onto a shipment, split into the steps both
/// the camera page and the PDA's trigger button go through: [precheck] on the
/// phone, [resolve] on the server, [confirm] with the worker when the carpet
/// is not simply this client's own, then [apply] to the form.
class ShipmentScanFlow {
  final ShipmentRepository repo;
  final ShipmentFormController controller;
  final int clientId;
  final String clientName;

  const ShipmentScanFlow({
    required this.repo,
    required this.controller,
    required this.clientId,
    required this.clientName,
  });

  /// Refusals that need no round trip. A carpet number already on the form
  /// is the same physical carpet scanned twice; the product barcode sits
  /// right next to the carpet number and names no single carpet.
  ShipmentScanRejection? precheck(String code) {
    if (isCarpetNumber(code)) {
      final row = controller.rowWithCarpet(code);
      if (row != null) {
        return ShipmentScanRejection(
          'Allaqachon qo\'shilgan',
          message: 'Bu gilam yuk xatida bor: ${_titleOfRow(row)}.\n'
              'Kod: $code',
          isWarning: true,
        );
      }
    }
    if (code.startsWith(productBarcodePrefix) && isEan13(code)) {
      return const ShipmentScanRejection(
        'Boshqa kodni skanerlang',
        message: 'Bu mahsulot shtrix-kodi. Yorliqning o\'ng yuqori '
            'burchagidagi 21 bilan boshlanadigan kodni yoki kvadrat '
            'kodni skanerlang.',
        isWarning: true,
      );
    }
    return null;
  }

  /// Asks the server which open order line, if any, the carpet ships on.
  Future<(ShipmentImportItemEntity?, ShipmentScanRejection?)> resolve(
      String code) async {
    try {
      final result = await repo.getShipmentScanItem(
        code: code,
        clientId: clientId,
        inForm: controller.quantitiesByOrderItem,
      );
      final (ShipmentImportItemEntity?, ShipmentScanRejection?) outcome =
          result.fold(
        (failure) => (
          null,
          ShipmentScanRejection(errorTitle(failure), message: failure.message),
        ),
        (item) => (item, null),
      );
      return outcome;
    } catch (e) {
      return (null, ShipmentScanRejection('Skanerlashda xatolik', message: '$e'));
    }
  }

  /// Whether the carpet needs the worker's say-so: this client never ordered
  /// it, or it was made for somebody else.
  static bool needsConfirmation(ShipmentImportItemEntity item) =>
      !item.isOnClientOrder || item.producedForClient != null;

  /// Two gates before a carpet that is not simply this client's own is added.
  ///
  /// The first sheet explains what is true about this particular carpet — it
  /// was made for someone else, this client never ordered it, it was never
  /// booked into the warehouse — because none of that is visible from the
  /// shipment form. The second is a plain yes/no naming the one consequence
  /// that is hard to undo: another client's ready count drops, or stock goes
  /// out. A worker scanning fifty carpets moves fast, and the sheet alone was
  /// one tap away from being dismissed on autopilot.
  Future<bool> confirm(
      BuildContext context, ShipmentImportItemEntity item) async {
    if (!needsConfirmation(item)) return true;

    // Neither accepted nor rejected — a lighter tap that says "look at me".
    HapticFeedback.selectionClick();

    final proceed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _ScannedItemSheet(
        item: item,
        clientName: clientName,
      ),
    );
    if (proceed != true || !context.mounted) return false;

    return _confirmFinalAdd(context, item);
  }

  Future<bool> _confirmFinalAdd(
      BuildContext context, ShipmentImportItemEntity item) async {
    final producedFor = item.producedForClient;

    final consequence = producedFor != null
        ? '"$producedFor" mijozining tayyor mahsuloti 1 taga kamayadi va bu '
            'gilam "$clientName" yuk xatiga qo\'shiladi. '
            'Ularning buyurtmasi qayta ishlab chiqarishga qaytadi.'
        : item.isBeyondOrder
            ? 'Bu gilam buyurtmadan ortiqcha bo\'lib "$clientName" '
                'yuk xatiga qo\'shiladi. Yuk xati saqlanganda unga yangi '
                'buyurtma qatori ochiladi.'
            : 'Bu gilam ombordan chiqariladi va "$clientName" yuk '
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
              backgroundColor:
                  producedFor != null ? AppColors.warning : AppColors.success,
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

  /// Puts the carpet on the form. [code] is kept on the row when it is a
  /// carpet number, so the same carpet cannot be scanned on twice.
  ShipmentScanOutcome? apply(ShipmentImportItemEntity item, String code) {
    final result = controller.addOrIncrementItem(
      item,
      carpetNumber: isCarpetNumber(code) ? code : null,
    );
    final row = controller.rowOf(item.variantId);
    if (row == null) return null;

    final title = item.edgeCode != null
        ? '${item.productName} [${item.edgeCode}]'
        : item.productName;
    final subtitle = [
      if (item.colorName != null) item.colorName!.toUpperCase(),
      if (item.sizeLabel != null) item.sizeLabel!,
    ].join(' · ');

    return ShipmentScanOutcome(
      row: row,
      incremented: result == ScanAddResult.incremented,
      title: [title, if (subtitle.isNotEmpty) subtitle].join(' · '),
    );
  }

  /// A short headline for a failed scan, with the server's own sentence kept
  /// underneath it, so a dead signal reads differently from a wrong label.
  static String errorTitle(Failure failure) {
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

  static String _titleOfRow(ShipmentItemRow row) => [
        row.edgeCode != null
            ? '${row.productName} [${row.edgeCode}]'
            : row.productName,
        if (row.colorName != null) row.colorName!.toUpperCase(),
      ].join(' · ');
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
