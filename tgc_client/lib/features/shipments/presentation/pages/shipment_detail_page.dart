import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/pages/pdf_viewer.dart';
import '../../../../core/ui/widgets/app_badge.dart';
import '../../../../core/ui/widgets/info_section.dart';
import '../../../../core/ui/widgets/typograpthy.dart';
import '../../domain/entities/shipment_entity.dart';
import '../../domain/entities/shipment_item_entity.dart';
import '../bloc/shipment_detail_cubit.dart';
import '../widgets/price_input.dart';

/// One shipment, and the page where it gets its prices.
///
/// Shipments are created in the warehouse without prices — a worker loading a
/// lorry should not be guessing what the client pays — so this is where the
/// office turns a loaded lorry into money: open the shipment, fill in the
/// lines, save. Saving recomputes what the client owes and regenerates the
/// hisob-faktura, which is why the invoice is downloaded from here and not
/// from the list.
class ShipmentDetailPage extends StatelessWidget {
  final int shipmentId;

  const ShipmentDetailPage({super.key, required this.shipmentId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ShipmentDetailCubit>()..load(shipmentId),
      child: _ShipmentDetailView(shipmentId: shipmentId),
    );
  }
}

class _ShipmentDetailView extends StatefulWidget {
  final int shipmentId;

  const _ShipmentDetailView({required this.shipmentId});

  @override
  State<_ShipmentDetailView> createState() => _ShipmentDetailViewState();
}

class _ShipmentDetailViewState extends State<_ShipmentDetailView> {
  /// One controller per shipment line, kept here rather than in the item
  /// widgets so a rebuild — including the one after saving — cannot drop what
  /// somebody has typed.
  final Map<int, TextEditingController> _priceCtrls = {};

  /// True once a price has been edited and not yet saved. Guards both leaving
  /// the page and downloading a hisob-faktura the server has not seen.
  bool _dirty = false;

  @override
  void dispose() {
    for (final ctrl in _priceCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  /// Creates a controller per line, and — when [fromServer] — resets them to
  /// what the server now holds. A price of 0 shows as an empty field: the
  /// point of this page is to tell "not priced yet" from "priced at zero".
  void _syncControllers(ShipmentEntity shipment, {bool fromServer = false}) {
    final live = <int>{};

    for (final item in shipment.items) {
      live.add(item.id);
      final text = item.price > 0 ? item.price.toStringAsFixed(2) : '';
      final existing = _priceCtrls[item.id];

      if (existing == null) {
        _priceCtrls[item.id] = TextEditingController(text: text);
      } else if (fromServer) {
        existing.text = text;
      }
    }

    for (final id in _priceCtrls.keys.toList()) {
      if (!live.contains(id)) _priceCtrls.remove(id)?.dispose();
    }
  }

  double _priceOf(int itemId) {
    final text = _priceCtrls[itemId]?.text.trim().replaceAll(',', '.') ?? '';
    return double.tryParse(text) ?? 0.0;
  }

  /// Same rule as the server and the shipment list: per piece, or per m².
  double _lineTotal(ShipmentItemEntity item) => item.productUnit == 'piece'
      ? _priceOf(item.id) * item.quantity
      : _priceOf(item.id) * item.squareMeters;

  double _grandTotal(ShipmentEntity shipment) =>
      shipment.items.fold(0.0, (sum, item) => sum + _lineTotal(item));

  int _unpricedCount(ShipmentEntity shipment) =>
      shipment.items.where((item) => _priceOf(item.id) <= 0).length;

  Future<void> _save(ShipmentEntity shipment) async {
    final unpriced = _unpricedCount(shipment);

    if (unpriced > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Narxsiz qatorlar bor'),
          content: Text(
            '$unpriced ta qatorning narxi kiritilmagan. Ular 0.00 bo\'lib '
            'saqlanadi va hisob-fakturada ham shunday chiqadi. Davom etasizmi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Saqlash'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final prices = {
      for (final item in shipment.items) item.id: _priceOf(item.id),
    };

    final saved =
        await context.read<ShipmentDetailCubit>().savePrices(shipment.id, prices);
    if (!mounted) return;

    if (saved) setState(() => _dirty = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'Narxlar saqlandi. Hisob-faktura yangilandi.'
            : 'Narxlarni saqlab bo\'lmadi.'),
        backgroundColor: saved ? AppColors.success : AppColors.error,
      ),
    );
  }

  /// Fills every empty price with what this client last paid for that variant.
  /// Explicit rather than automatic: a suggested price that appears on its own
  /// is one nobody checks before saving.
  Future<void> _fillFromLastPrices(ShipmentEntity shipment) async {
    final cubit = context.read<ShipmentDetailCubit>();
    final prices = await cubit.lastPricesForShipment(shipment);
    if (!mounted) return;

    var filled = 0;
    for (final item in shipment.items) {
      final variantId = item.variantId;
      if (variantId == null) continue;
      if (_priceOf(item.id) > 0) continue;

      final last = prices[variantId];
      if (last == null) continue;

      _priceCtrls[item.id]?.text = last.toStringAsFixed(2);
      filled++;
    }

    setState(() => _dirty = _dirty || filled > 0);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(filled > 0
            ? '$filled ta qatorga oxirgi narx qo\'yildi. Tekshirib, saqlang.'
            : 'Oxirgi narxlar topilmadi.'),
      ),
    );
  }

  void _openInvoice(ShipmentEntity shipment) {
    if (_dirty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avval narxlarni saqlang, keyin hisob-fakturani oling.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (shipment.invoiceUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hisob-faktura hali tayyor emas. Narxlarni saqlang.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => PdfViewerPage(
          title: 'Hisob-faktura ${shipment.id}',
          pdfUrl: shipment.invoiceUrl!,
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Saqlanmagan narxlar'),
        content: const Text(
          'Kiritilgan narxlar saqlanmadi. Sahifadan chiqsangiz, ular yo\'qoladi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Qolish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Chiqish'),
          ),
        ],
      ),
    );
    return leave == true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ShipmentDetailCubit, ShipmentDetailState>(
      listener: (context, state) {
        // A save is the one moment the server's numbers should overwrite the
        // fields; every other rebuild leaves typing in progress alone.
        if (state is ShipmentDetailLoaded && state.justSaved) {
          _syncControllers(state.shipment, fromServer: true);
        }
      },
      builder: (context, state) {
        final shipment = state is ShipmentDetailLoaded ? state.shipment : null;
        final isSaving = state is ShipmentDetailLoaded && state.isSaving;

        return PopScope(
          canPop: !_dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmDiscard() && context.mounted) context.pop();
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text('#${widget.shipmentId} Yuk xati'),
              titleSpacing: 0,
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
              ),
              actions: [
                if (shipment != null && !shipment.isCanceled) ...[
                  IconButton(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedInvoice02,
                      size: 20,
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                    tooltip: 'Hisob-faktura',
                    onPressed: () => _openInvoice(shipment),
                  ),
                  if (isSaving)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => _save(shipment),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Saqlash'),
                    ),
                ],
                const SizedBox(width: 16),
              ],
            ),
            body: _buildBody(context, state),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ShipmentDetailState state) {
    if (state is ShipmentDetailLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is ShipmentDetailError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context
                    .read<ShipmentDetailCubit>()
                    .load(widget.shipmentId),
                child: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is ShipmentDetailLoaded) {
      final shipment = state.shipment;

      // Here rather than only in the listener: nothing guarantees a listener
      // runs before the first build of the same state, and every row below
      // reads its controller by id.
      _syncControllers(shipment);

      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ShipmentInfoCard(
                shipment: shipment,
                grandTotal: _grandTotal(shipment),
              ),
              const SizedBox(height: 20),
              _PricedItemsCard(
                shipment: shipment,
                priceCtrls: _priceCtrls,
                lineTotal: _lineTotal,
                grandTotal: _grandTotal(shipment),
                unpricedCount: _unpricedCount(shipment),
                editable: !shipment.isCanceled,
                onPriceChanged: () => setState(() => _dirty = true),
                onFillLastPrices: () => _fillFromLastPrices(shipment),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Header card ─────────────────────────────────────────────────────────────

class _ShipmentInfoCard extends StatelessWidget {
  final ShipmentEntity shipment;
  final double grandTotal;

  const _ShipmentInfoCard({required this.shipment, required this.grandTotal});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Yuk xati ma\'lumotlari',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 12),
                if (shipment.isCanceled)
                  const AppBadge(
                    label: 'Bekor qilingan',
                    color: AppColors.error,
                  )
                else if (grandTotal <= 0)
                  const AppBadge(
                    label: 'Narx kiritilmagan',
                    color: AppColors.warning,
                  )
                else
                  const AppBadge(label: 'Narxlangan', color: AppColors.success),
              ],
            ),
            const SizedBox(height: 16),
            InfoSection(items: [
              InfoSectionItemData(label: 'ID', value: '#${shipment.id}'),
              InfoSectionItemData(
                label: 'Sana',
                value: _formatDateTime(shipment.shipmentDatetime),
              ),
              InfoSectionItemData(
                label: 'Mijoz',
                value: '${shipment.clientShopName ?? '—'} / '
                    '${shipment.clientRegion ?? '—'}',
              ),
              InfoSectionItemData(label: 'Xodim', value: shipment.userName ?? '—'),
              InfoSectionItemData(
                label: 'Jami dona',
                value: '${shipment.totalQuantity} ta',
              ),
              InfoSectionItemData(
                label: 'Jami m²',
                value: '${shipment.totalM2.toStringAsFixed(2)} m²',
              ),
              InfoSectionItemData(
                label: 'Jami summa',
                value: '\$${grandTotal.toStringAsFixed(2)}',
              ),
            ]),
            if (shipment.isCanceled && shipment.cancelReason != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'Bekor qilish sababi: ${shipment.cancelReason}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.error),
              ),
            ],
            if (shipment.notes != null && shipment.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              BodyText(text: 'Izoh: ${shipment.notes}'),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Items + price editor ────────────────────────────────────────────────────

class _PricedItemsCard extends StatelessWidget {
  final ShipmentEntity shipment;
  final Map<int, TextEditingController> priceCtrls;
  final double Function(ShipmentItemEntity) lineTotal;
  final double grandTotal;
  final int unpricedCount;
  final bool editable;
  final VoidCallback onPriceChanged;
  final VoidCallback onFillLastPrices;

  const _PricedItemsCard({
    required this.shipment,
    required this.priceCtrls,
    required this.lineTotal,
    required this.grandTotal,
    required this.unpricedCount,
    required this.editable,
    required this.onPriceChanged,
    required this.onFillLastPrices,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mahsulotlar va narxlar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (editable && unpricedCount > 0)
                  TextButton.icon(
                    onPressed: onFillLastPrices,
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Oxirgi narxlar'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          LayoutBuilder(builder: (context, constraints) {
            final isMobile =
                constraints.maxWidth < AppConstants.desktopBreakpoint;

            return isMobile
                ? _buildMobileList(context)
                : _buildDesktopTable(context);
          }),
        ],
      ),
    );
  }

  // On a phone every line is a block with the price field under it: the
  // office types into these one after another, and a horizontally scrolling
  // table would put the field they are aiming at off screen.
  Widget _buildMobileList(BuildContext context) {
    return Column(
      children: [
        ...shipment.items.asMap().entries.expand((entry) sync* {
          yield _buildMobileRow(context, entry.key, entry.value);
          if (entry.key < shipment.items.length - 1) {
            yield const Divider(height: 1, color: AppColors.divider);
          }
        }),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildMobileRow(
    BuildContext context,
    int index,
    ShipmentItemEntity item,
  ) {
    return Container(
      color: index.isOdd ? AppColors.surface.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BodyText(
            text: '${index + 1}. ${_itemTitle(item)}',
            fontWeight: FontWeight.w600,
          ),
          const SizedBox(height: 2),
          SubBodyText(text: _itemSubtitle(item)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: BodyText(text: _quantityLabel(item)),
              ),
              SizedBox(
                width: 120,
                child: _priceField(context, item),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 90,
                child: Text(
                  '\$${lineTotal(item).toStringAsFixed(2)}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: AppColors.primary.withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(width: 40, child: Text('#', style: labelStyle)),
              Expanded(flex: 3, child: Text('Mahsulot', style: labelStyle)),
              Expanded(flex: 3, child: Text('Rang / O\'lcham', style: labelStyle)),
              SizedBox(width: 110, child: Text('Miqdor', style: labelStyle)),
              SizedBox(width: 130, child: Text('Narx', style: labelStyle)),
              SizedBox(
                width: 110,
                child: Text('Jami', style: labelStyle, textAlign: TextAlign.end),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        ...shipment.items.asMap().entries.expand((entry) sync* {
          yield _buildDesktopRow(context, entry.key, entry.value);
          if (entry.key < shipment.items.length - 1) {
            yield const Divider(height: 1, color: AppColors.divider);
          }
        }),
        _buildFooter(context),
      ],
    );
  }

  Widget _buildDesktopRow(
    BuildContext context,
    int index,
    ShipmentItemEntity item,
  ) {
    return Container(
      color: index.isOdd ? AppColors.surface.withValues(alpha: 0.5) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(width: 40, child: BodyText(text: '${index + 1}')),
          Expanded(
            flex: 3,
            child: BodyText(
              text: _itemTitle(item),
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(flex: 3, child: BodyText(text: _itemSubtitle(item))),
          SizedBox(width: 110, child: BodyText(text: _quantityLabel(item))),
          SizedBox(
            width: 130,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _priceField(context, item),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              '\$${lineTotal(item).toStringAsFixed(2)}',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// The price cell. A cancelled shipment shows what it went out at and
  /// nothing more — its debt was already dropped, so there is nothing left to
  /// price, and an editable field would only invite a save that is refused.
  Widget _priceField(BuildContext context, ShipmentItemEntity item) {
    if (!editable) {
      return Text(
        '\$${item.price.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return PriceInput(
      priceCtrl: priceCtrls[item.id]!,
      onChanged: onPriceChanged,
    );
  }

  Widget _buildFooter(BuildContext context) {
    final footerStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        );

    return Container(
      color: AppColors.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              unpricedCount > 0
                  ? 'Jami ($unpricedCount ta qator narxsiz)'
                  : 'Jami',
              style: footerStyle,
            ),
          ),
          Text('\$${grandTotal.toStringAsFixed(2)}', style: footerStyle),
        ],
      ),
    );
  }
}

// ── Shared formatting ───────────────────────────────────────────────────────

String _itemTitle(ShipmentItemEntity item) => item.edgeCode != null
    ? '${item.productName ?? '—'} [${item.edgeCode}]'
    : item.productName ?? '—';

String _itemSubtitle(ShipmentItemEntity item) {
  final parts = [
    if (item.colorName != null) item.colorName!.toUpperCase(),
    if (item.sizeLength != null && item.sizeWidth != null)
      '${item.sizeWidth}×${item.sizeLength}',
  ];
  return parts.isEmpty ? '—' : parts.join(' · ');
}

/// What the price is per — the office is typing a rate, and for a carpet sold
/// by area that rate is per m², not per carpet.
String _quantityLabel(ShipmentItemEntity item) => item.productUnit == 'piece'
    ? '${item.quantity} dona'
    : '${item.quantity} dona · ${item.squareMeters.toStringAsFixed(2)} m²';

String _formatDateTime(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  final mo = date.month.toString().padLeft(2, '0');
  return '$d.$mo.${date.year} $h:$m';
}
