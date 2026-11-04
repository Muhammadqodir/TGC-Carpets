import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_thumbnail.dart';
import '../../../../core/ui/widgets/count_input.dart';
import '../../domain/entities/shipment_import_entities.dart';
import '../bloc/shipment_import_bloc.dart';
import '../bloc/shipment_import_event.dart';
import '../bloc/shipment_import_state.dart';

// ── Result ─────────────────────────────────────────────────────────────────────

class OrderListPickResult {
  final List<ShipmentPickSelection> selections;
  final ShipmentImportClientEntity client;
  const OrderListPickResult({required this.selections, required this.client});
}

// ── Sheet ──────────────────────────────────────────────────────────────────────

/// Loading a lorry by hand instead of by scanning: every carpet the client
/// still owes, grouped by size, ticked and counted.
///
///   1. Pick a client — skipped when the form already has one.
///   2. Tick carpets and set how many of each, filtered by quality or search.
///
/// The warehouse plays no part: every open order line is listed. Returns
/// [OrderListPickResult], or null if dismissed.
class OrderListPickerSheet extends StatelessWidget {
  const OrderListPickerSheet({super.key, this.client, this.onForm = const {}});

  /// The client on the shipment form, if any; the list is locked to them.
  final ShipmentImportClientEntity? client;

  /// How many of each carpet the form already holds, by variant id.
  final Map<int, int> onForm;

  static Future<OrderListPickResult?> show(
    BuildContext context, {
    ShipmentImportClientEntity? client,
    Map<int, int> onForm = const {},
  }) {
    return showModalBottomSheet<OrderListPickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OrderListPickerSheet(client: client, onForm: onForm),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ShipmentImportBloc>()
        ..add(ShipmentImportStarted(client: client, onForm: onForm)),
      child: BlocConsumer<ShipmentImportBloc, ShipmentImportState>(
        listener: (context, state) {
          if (state is ShipmentImportDone) {
            Navigator.of(context).pop(OrderListPickResult(
              selections: state.selections,
              client: state.client,
            ));
          }
        },
        builder: (context, state) => _SheetBody(state: state),
      ),
    );
  }
}

// ── Sheet body ─────────────────────────────────────────────────────────────────

class _SheetBody extends StatelessWidget {
  final ShipmentImportState state;
  const _SheetBody({required this.state});

  bool get _showBack =>
      state is ShipmentImportItemsLoaded &&
      (state as ShipmentImportItemsLoaded).allClients != null;

  String get _titleText {
    if (state is ShipmentImportItemsLoaded) {
      return (state as ShipmentImportItemsLoaded).client.displayName;
    }
    return 'Mijozni tanlang';
  }

  String get _subtitleText {
    if (state is ShipmentImportItemsLoaded) {
      return 'Buyurtmadagi mahsulotlar · o\'lcham bo\'yicha';
    }
    return 'Ochiq buyurtmasi bor mijozlar';
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ShipmentImportBloc>();
    final itemsState =
        state is ShipmentImportItemsLoaded ? state as ShipmentImportItemsLoaded : null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                if (_showBack)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () =>
                        bloc.add(const ShipmentImportBackPressed()),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _titleText,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _subtitleText,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content area
          Flexible(child: _buildContent(context, bloc)),

          // Confirm button (items step only)
          if (itemsState != null && itemsState.anySelected)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: () => bloc.add(const ShipmentImportConfirmed()),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    'Qo\'shish · ${itemsState.selectedCount} ta mahsulot, '
                    '${itemsState.selectedQuantity} dona',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ShipmentImportBloc bloc) {
    if (state is ShipmentImportLoading || state is ShipmentImportInitial) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (state is ShipmentImportError) {
      final err = state as ShipmentImportError;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                err.message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => bloc.add(const ShipmentImportBackPressed()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is ShipmentImportClientsLoaded) {
      return _ClientsList(
        clients: (state as ShipmentImportClientsLoaded).clients,
        onSelect: (c) => bloc.add(ShipmentImportClientSelected(c)),
      );
    }

    if (state is ShipmentImportItemsLoaded) {
      return _ItemsList(state: state as ShipmentImportItemsLoaded);
    }

    return const SizedBox.shrink();
  }
}

// ── Step 1: Clients ────────────────────────────────────────────────────────────

class _ClientsList extends StatelessWidget {
  final List<ShipmentImportClientEntity> clients;
  final ValueChanged<ShipmentImportClientEntity> onSelect;
  const _ClientsList({required this.clients, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (clients.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Ochiq buyurtma topilmadi',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: clients.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final c = clients[i];
        return InkWell(
          onTap: () => onSelect(c),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      c.shopName.isNotEmpty
                          ? c.shopName[0].toUpperCase()
                          : '?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.shopName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        c.region,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _CountBadge(label: '${c.itemCount} ta'),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Step 2: Items, by size ─────────────────────────────────────────────────────

/// One entry of the flattened list: a size header or a carpet under it.
sealed class _Entry {}

class _HeaderEntry extends _Entry {
  final ShipmentPickGroup group;
  _HeaderEntry(this.group);
}

class _ItemEntry extends _Entry {
  final ShipmentPickItem item;
  _ItemEntry(this.item);
}

class _ItemsList extends StatelessWidget {
  final ShipmentImportItemsLoaded state;
  const _ItemsList({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ShipmentImportBloc>();

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Bu mijozning ochiq buyurtmasi yo\'q',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final visible = state.visibleItems;
    final groups = state.groups;
    final entries = <_Entry>[
      for (final g in groups) ...[
        _HeaderEntry(g),
        for (final i in g.items) _ItemEntry(i),
      ],
    ];
    final qualities = state.qualities;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: TextField(
            onChanged: (q) => bloc.add(ShipmentImportSearchChanged(q)),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Qidirish: nomi, rangi, o\'lchami',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),

        // Quality filter — only worth a row when there is a choice.
        if (qualities.length > 1)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _FilterChip(
                  label: 'Barchasi (${state.items.length})',
                  selected: state.qualityFilter == null,
                  onTap: () => bloc
                      .add(const ShipmentImportQualityFilterChanged(null)),
                ),
                for (final q in qualities)
                  _FilterChip(
                    label: '${q.qualityName} (${q.itemCount})',
                    selected: state.qualityFilter == q.qualityName,
                    onTap: () => bloc
                        .add(ShipmentImportQualityFilterChanged(q.qualityName)),
                  ),
              ],
            ),
          ),

        // Select-all toggle over what is shown
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${visible.length} ta mahsulot · '
                  '${visible.fold<int>(0, (s, i) => s + state.offeredOf(i))} dona qolgan',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              Text(
                'Hammasi',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              Switch(
                value: state.allSelected(visible),
                onChanged: (v) => bloc.add(ShipmentImportSelectionSet(
                  [for (final i in visible) i.variantId],
                  select: v,
                )),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),

        Flexible(
          child: entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Hech narsa topilmadi',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => switch (entries[i]) {
                    _HeaderEntry(:final group) => _SizeHeader(
                        group: group,
                        state: state,
                      ),
                    _ItemEntry(:final item) => _PickTile(
                        key: ValueKey(item.variantId),
                        item: item,
                        offered: state.offeredOf(item),
                        onForm: state.onForm[item.variantId] ?? 0,
                        quantity: state.selected[item.variantId],
                      ),
                  },
                ),
        ),
      ],
    );
  }
}

/// "200×300 · 6 ta · 14 dona", with a tick for the whole size.
class _SizeHeader extends StatelessWidget {
  final ShipmentPickGroup group;
  final ShipmentImportItemsLoaded state;
  const _SizeHeader({required this.group, required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ShipmentImportBloc>();
    final left = group.items.fold<int>(0, (s, i) => s + state.offeredOf(i));
    final selectable = group.items.any(state.isSelectable);
    final all = state.allSelected(group.items);

    return Container(
      color: AppColors.primary.withValues(alpha: 0.06),
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          const Icon(Icons.straighten_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            group.sizeLabel ?? 'O\'lchamsiz',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${group.items.length} ta · $left dona',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Checkbox(
            value: all,
            onChanged: selectable
                ? (v) => bloc.add(ShipmentImportSelectionSet(
                      [for (final i in group.items) i.variantId],
                      select: v ?? false,
                    ))
                : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// One carpet: tick it, then set how many. Owns the quantity field's
/// controller and keeps it in step with the bloc, which clamps what is typed.
class _PickTile extends StatefulWidget {
  final ShipmentPickItem item;
  final int offered;
  final int onForm;

  /// Null when not ticked.
  final int? quantity;

  const _PickTile({
    super.key,
    required this.item,
    required this.offered,
    required this.onForm,
    required this.quantity,
  });

  @override
  State<_PickTile> createState() => _PickTileState();
}

class _PickTileState extends State<_PickTile> {
  late final TextEditingController _qty =
      TextEditingController(text: '${widget.quantity ?? widget.offered}');

  @override
  void didUpdateWidget(covariant _PickTile old) {
    super.didUpdateWidget(old);
    final q = widget.quantity;
    if (q != null && int.tryParse(_qty.text) != q) _qty.text = '$q';
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _quantityEdited() {
    final typed = int.tryParse(_qty.text);
    if (typed == null) return; // half-typed; wait for a number
    context
        .read<ShipmentImportBloc>()
        .add(ShipmentImportItemQuantityChanged(widget.item.variantId, typed));
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ShipmentImportBloc>();
    final f = widget.item.first;
    final selectable = widget.offered > 0;
    final selected = widget.quantity != null;
    final small = Theme.of(context).textTheme.labelSmall;

    final orders = widget.item.orderIds.map((id) => '#$id').toList();
    final ordersText = orders.length > 3
        ? '${orders.take(3).join(', ')} +${orders.length - 3}'
        : orders.join(', ');

    return InkWell(
      onTap: selectable
          ? () => bloc.add(ShipmentImportItemToggled(widget.item.variantId))
          : null,
      child: Opacity(
        opacity: selectable ? 1 : 0.5,
        child: Container(
          color: selected ? AppColors.primary.withValues(alpha: 0.04) : null,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: selected,
                  onChanged: null, // handled by the InkWell
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              AppThumbnail(imageUrl: f.colorImageUrl, size: 36, borderRadius: 6),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        f.edgeCode != null
                            ? '${f.productName} [${f.edgeCode}]'
                            : f.productName,
                        if (f.colorName != null) f.colorName!.toUpperCase(),
                      ].join(' / '),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        if (f.qualityName != null) _Chip(label: f.qualityName!),
                        if (f.typeName != null) _Chip(label: f.typeName!),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (ordersText.isNotEmpty) ordersText,
                        'qolgan ${widget.item.remaining} dona',
                        if (widget.onForm > 0) 'formada ${widget.onForm}',
                      ].join(' · '),
                      style: small?.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (selected)
                SizedBox(
                  width: 112,
                  child: CountInput(
                    controller: _qty,
                    min: 1,
                    max: widget.offered,
                    height: 34,
                    onChanged: _quantityEdited,
                  ),
                )
              else if (selectable)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.offered}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                    ),
                    Text(
                      f.productUnit == 'sqm' ? 'm²' : 'dona',
                      style: small?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                )
              else
                Text(
                  'Formada',
                  style: small?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small pieces ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final String label;
  const _CountBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    const c = AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: c,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
