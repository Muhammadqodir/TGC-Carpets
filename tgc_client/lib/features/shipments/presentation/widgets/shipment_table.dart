import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/pages/pdf_viewer.dart';
import 'package:tgc_client/core/ui/widgets/app_data_table.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';
import 'package:tgc_client/core/utils/excel_downloader.dart';

import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/shipment_entity.dart';
import '../../domain/repositories/shipment_repository.dart';
import '../bloc/shipments_bloc.dart';
import '../bloc/shipments_event.dart';

/// Shipments data table that wraps the generic [AppDataTable].
class ShipmentTable extends StatelessWidget {
  const ShipmentTable({
    super.key,
    required this.shipments,
    required this.isLoadingMore,
    required this.scrollController,
  });

  final List<ShipmentEntity> shipments;
  final bool isLoadingMore;
  final ScrollController scrollController;


  static const _columns = <AppTableColumn>[
    AppTableColumn(label: 'ID', fixedWidth: 68, alignment: Alignment.center),
    AppTableColumn(label: 'Sana', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Mijoz / Hudud', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Buyurtma', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(label: 'Hajm', flex: 3, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Jami (m²)', flex: 2, alignment: Alignment.centerRight),
    AppTableColumn(label: 'Izoh', flex: 3, alignment: Alignment.center),
    AppTableColumn(label: '', fixedWidth: 144, alignment: Alignment.center),
  ];

  static const _mobileColumns = <AppTableColumn>[
    AppTableColumn(label: 'Yuk', flex: 2, alignment: Alignment.centerLeft),
    AppTableColumn(
        label: 'Hajm', flex: 1, alignment: Alignment.centerRight),
    AppTableColumn(label: '', fixedWidth: 40, alignment: Alignment.center),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < AppConstants.desktopBreakpoint;
      final columns = isMobile ? _mobileColumns : _columns;

      return AppDataTable<ShipmentEntity>(
        items: shipments,
        columns: columns,
        scrollController: scrollController,
        isLoadingMore: isLoadingMore,
        cellBuilder: (context, shipment, colIndex) => isMobile
            ? _buildMobileCell(context, shipment, colIndex)
            : _buildCell(context, shipment, colIndex),
      );
    });
  }

  Widget _buildMobileCell(
    BuildContext context,
    ShipmentEntity shipment,
    int colIndex,
  ) {
    switch (colIndex) {
      case 0: // ID
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BodyText(
              text:
                  "${shipment.clientShopName ?? '—'}/${shipment.clientRegion ?? '—'}",
              textAlign: TextAlign.left,
            ),
            BodyText(
              text: _formatDateTime(shipment.shipmentDatetime),
            ),
            if (shipment.isCanceled)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: _CanceledBadge(),
              ),
          ],
        );

      case 1: // Total m²
        final m2 = shipment.totalM2;
        final totalQty = shipment.totalQuantity;
        return Text(
          '$totalQty dona\n${m2 > 0 ? '${m2.toStringAsFixed(1)} m²' : '—'}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.left,
        );

      case 2: // PDF actions
        return _buildActions(context, shipment, isMobile: true);

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCell(
      BuildContext context, ShipmentEntity shipment, int colIndex) {
    switch (colIndex) {
      case 0: // ID
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${shipment.id}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    decoration:
                        shipment.isCanceled ? TextDecoration.lineThrough : null,
                  ),
            ),
            if (shipment.isCanceled) const _CanceledBadge(),
          ],
        );

      case 1: // Date
        return Text(
          _formatDateTime(shipment.shipmentDatetime),
          style: Theme.of(context).textTheme.bodyMedium,
        );

      case 2: // Client / Region
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shipment.clientShopName ?? '—',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (shipment.clientRegion != null &&
                shipment.clientRegion!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                shipment.clientRegion!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );

      case 3: // Order dates
        return _OrderDatesCell(shipment: shipment);

      case 4: // Volume
        return _VolumeCell(shipment: shipment);

      case 5: // Total m²
        final m2 = shipment.totalM2;
        return Text(
          m2 > 0 ? '${m2.toStringAsFixed(1)} m²' : '—',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.right,
        );

      case 6: // Notes
        return shipment.notes != null && shipment.notes!.isNotEmpty
            ? Text(
                shipment.notes!,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : Text(
                '—',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              );

      case 7: // PDF actions
        return _buildActions(context, shipment, isMobile: false);

      default:
        return const SizedBox.shrink();
    }
  }

  String _formatDateTime(DateTime date) {
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final mo = date.month.toString().padLeft(2, '0');
    return '$d.$mo.${date.year} $h:$m';
  }

  Widget _buildActions(
    BuildContext context,
    ShipmentEntity shipment, {
    required bool isMobile,
  }) {
    if (isMobile) {
      return PopupMenuButton<String>(
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedMoreVertical,
        ),
        surfaceTintColor: AppColors.surface,
        color: AppColors.surface,
        onSelected: (value) {
          switch (value) {
            case 'pdf':
              if (shipment.pdfUrl != null) {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (_) => PdfViewerPage(
                      title: 'Yuk xati ${shipment.id}',
                      pdfUrl: shipment.pdfUrl!,
                    ),
                  ),
                );
              }
              break;
            case 'xlsx':
              if (shipment.xlsxUrl != null) {
                _downloadXlsx(context, shipment);
              }
              break;
            case 'cancel':
              _confirmCancel(context, shipment);
              break;
          }
        },
        itemBuilder: (context) => [
          if (shipment.pdfUrl != null)
            PopupMenuItem(
              value: 'pdf',
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedInvoice01,
                    color: AppColors.primary,
                    size: 18,
                    strokeWidth: 2,
                  ),
                  const SizedBox(width: 8),
                  const Text('Yuk xati'),
                ],
              ),
            ),
          // No hisob-faktura here: it is only worth anything once prices are
          // filled in, which is the pricing feature's job — so that is where
          // it is downloaded from.
          if (shipment.xlsxUrl != null)
            PopupMenuItem(
              value: 'xlsx',
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedFileDownload,
                    color: AppColors.success,
                    strokeWidth: 2,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text('Excel yuklab olish'),
                ],
              ),
            ),
          if (_canCancel(context, shipment))
            const PopupMenuItem(
              value: 'cancel',
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined,
                      color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Text('Bekor qilish',
                      style: TextStyle(color: AppColors.error)),
                ],
              ),
            ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedInvoice01,
            color: shipment.pdfUrl != null
                ? AppColors.primary
                : AppColors.textSecondary,
            size: 22,
            strokeWidth: 1.5,
          ),
          tooltip: 'Yuk xati',
          color: AppColors.primary,
          onTap: shipment.pdfUrl != null
              ? () => Navigator.of(context).push(
                    CupertinoPageRoute(
                      builder: (_) => PdfViewerPage(
                        title: 'Yuk xati ${shipment.id}',
                        pdfUrl: shipment.pdfUrl!,
                      ),
                    ),
                  )
              : null,
        ),
        _ActionButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedFileDownload,
            color: shipment.xlsxUrl != null
                ? AppColors.success
                : AppColors.textSecondary,
            size: 22,
            strokeWidth: 1.5,
          ),
          tooltip: 'Excel yuklab olish',
          color: AppColors.success,
          onTap: shipment.xlsxUrl != null
              ? () => _downloadXlsx(context, shipment)
              : null,
        ),
        if (_canCancel(context, shipment))
          _ActionButton(
            icon: const Icon(Icons.cancel_outlined,
                color: AppColors.error, size: 22),
            tooltip: 'Bekor qilish',
            color: AppColors.error,
            onTap: () => _confirmCancel(context, shipment),
          ),
      ],
    );
  }

  /// Cancelling puts stock back and wipes the client's debt for the
  /// shipment, so it is admin-only — the backend enforces the same rule and
  /// answers 403 regardless of what the UI shows. An already-cancelled
  /// shipment cannot be cancelled twice.
  bool _canCancel(BuildContext context, ShipmentEntity shipment) {
    if (shipment.isCanceled) return false;

    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated && authState.user.isAdmin;
  }
}

/// Confirms, then cancels. The dialog states what cancelling actually does —
/// stock returns, the client's debt for this shipment disappears, the order
/// lines become unshipped — because none of that is visible from the row.
Future<void> _confirmCancel(
    BuildContext context, ShipmentEntity shipment) async {
  final reasonCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Yuk xati #${shipment.id} bekor qilinsinmi?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${shipment.clientShopName ?? '—'} · '
            '${shipment.totalQuantity} dona',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text(
            'Mahsulotlar omborga qaytariladi, buyurtma qatorlari yana '
            'yuborilmagan holatga o\'tadi va mijozning bu yuk xati '
            'bo\'yicha qarzi bekor qilinadi.',
            style: TextStyle(fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: reasonCtrl,
            maxLines: 2,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Sabab (ixtiyoriy)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Yopish'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          child: const Text('Bekor qilish'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) {
    reasonCtrl.dispose();
    return;
  }

  final messenger = ScaffoldMessenger.of(context);
  final bloc = context.read<ShipmentsBloc>();
  final result = await sl<ShipmentRepository>().cancelShipment(
    id: shipment.id,
    reason: reasonCtrl.text,
  );
  reasonCtrl.dispose();

  result.fold(
    (failure) => messenger.showSnackBar(SnackBar(
      content: Text(failure.message),
      backgroundColor: AppColors.error,
    )),
    (_) {
      messenger.showSnackBar(SnackBar(
        content: Text('Yuk xati #${shipment.id} bekor qilindi.'),
        backgroundColor: AppColors.success,
      ));
      // The row, the client's balance and every shipped quantity behind it
      // just changed server-side; reload rather than patch one row.
      bloc.add(const ShipmentsRefreshRequested());
    },
  );
}

Future<void> _downloadXlsx(
    BuildContext context, ShipmentEntity shipment) async {
  final url = shipment.xlsxUrl!;
  try {
    final response = await sl<Dio>().get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    if (response.data == null) return;
    final bytes = Uint8List.fromList(response.data!);
    await downloadExcel(bytes, 'shipment_${shipment.id}.xlsx');
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Excel yuklab olishda xatolik yuz berdi')),
      );
    }
  }
}

// ---------------------------------------------------------------------------

class _OrderDatesCell extends StatelessWidget {
  final ShipmentEntity shipment;

  const _OrderDatesCell({required this.shipment});

  @override
  Widget build(BuildContext context) {
    final dates = shipment.orderDates;
    if (dates.isEmpty) {
      return Text(
        '—',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textSecondary),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dates
          .map((d) => Text(
                _fmtDate(d),
                style: Theme.of(context).textTheme.bodyMedium,
              ))
          .toList(),
    );
  }

  String _fmtDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final mo = d.month.toString().padLeft(2, '0');
    return '$day.$mo.${d.year}';
  }
}

// ---------------------------------------------------------------------------

class _VolumeCell extends StatelessWidget {
  final ShipmentEntity shipment;

  const _VolumeCell({required this.shipment});

  @override
  Widget build(BuildContext context) {
    final itemCount = shipment.items.length;
    final totalQty = shipment.totalQuantity;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$itemCount xil • $totalQty dona',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

/// Marks a cancelled shipment in the list. The row stays — the document
/// existed and the cancellation is part of its history — but nothing about
/// it should read as a live delivery.
class _CanceledBadge extends StatelessWidget {
  const _CanceledBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'BEKOR QILINGAN',
        style: TextStyle(
          color: AppColors.error,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final Widget icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: icon,
        ),
      ),
    );
  }
}
