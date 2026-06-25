import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_thumbnail.dart';
import '../../domain/entities/shipment_import_entities.dart';
import '../bloc/shipment_import_bloc.dart';
import '../bloc/shipment_import_event.dart';
import '../bloc/shipment_import_state.dart';

// ── Result ─────────────────────────────────────────────────────────────────────

class StockImportResult {
  final List<ShipmentImportItemEntity> selectedItems;
  final ShipmentImportClientEntity client;
  const StockImportResult({required this.selectedItems, required this.client});
}

// ── Sheet ──────────────────────────────────────────────────────────────────────

/// Three-step bottom sheet for importing items from warehouse stock into a shipment:
///   1. Pick a client (clients who have stock-available order items).
///   2. Pick a quality.
///   3. Multi-select items to ship.
///
/// Returns [StockImportResult] or null if dismissed.
class StockPickerForShipmentSheet extends StatelessWidget {
  const StockPickerForShipmentSheet({super.key});

  static Future<StockImportResult?> show(BuildContext context) {
    return showModalBottomSheet<StockImportResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const StockPickerForShipmentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ShipmentImportBloc>()..add(const ShipmentImportStarted()),
      child: BlocConsumer<ShipmentImportBloc, ShipmentImportState>(
        listener: (context, state) {
          if (state is ShipmentImportDone) {
            Navigator.of(context).pop(StockImportResult(
              selectedItems: state.selectedItems,
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

  // ── Derived helpers ──────────────────────────────────────────────────────────

  bool get _showBack =>
      state is ShipmentImportQualitiesLoaded ||
      state is ShipmentImportItemsLoaded ||
      (state is ShipmentImportError &&
          (state as ShipmentImportError).previousState
              is! ShipmentImportInitial &&
          (state as ShipmentImportError).previousState
              is! ShipmentImportClientsLoaded);

  int get _stepIndex {
    final s = state is ShipmentImportError
        ? (state as ShipmentImportError).previousState
        : state;
    if (s is ShipmentImportQualitiesLoaded) return 1;
    if (s is ShipmentImportItemsLoaded) return 2;
    return 0;
  }

  String get _titleText {
    if (state is ShipmentImportQualitiesLoaded) {
      return (state as ShipmentImportQualitiesLoaded).client.displayName;
    }
    if (state is ShipmentImportItemsLoaded) {
      return (state as ShipmentImportItemsLoaded).quality.qualityName;
    }
    return 'Mijozni tanlang';
  }

  String get _subtitleText {
    if (state is ShipmentImportQualitiesLoaded) return 'Sifat turini tanlang';
    if (state is ShipmentImportItemsLoaded) {
      return (state as ShipmentImportItemsLoaded).client.displayName;
    }
    return 'Omborda mavjud buyurtmalar';
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ShipmentImportBloc>();
    final isItems = state is ShipmentImportItemsLoaded;
    final itemsState = isItems ? state as ShipmentImportItemsLoaded : null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
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

          // Step indicator
          if (state is! ShipmentImportLoading)
            _StepIndicator(stepIndex: _stepIndex),

          // Content area
          Flexible(child: _buildContent(context, bloc)),

          // Confirm button (items step only)
          if (isItems && itemsState!.anySelected)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: () => bloc.add(const ShipmentImportConfirmed()),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    'Import qilish (${itemsState.selectedIds.length} ta mahsulot)',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ShipmentImportBloc bloc) {
    if (state is ShipmentImportLoading) {
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

    if (state is ShipmentImportQualitiesLoaded) {
      return _QualitiesList(
        qualities: (state as ShipmentImportQualitiesLoaded).qualities,
        onSelect: (q) => bloc.add(ShipmentImportQualitySelected(q)),
      );
    }

    if (state is ShipmentImportItemsLoaded) {
      return _ItemsList(
        state: state as ShipmentImportItemsLoaded,
        onToggle: (id) => bloc.add(ShipmentImportItemToggled(id)),
        onToggleAll: (v) => bloc.add(ShipmentImportSelectAllToggled(v)),
      );
    }

    return const SizedBox.shrink();
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int stepIndex;
  const _StepIndicator({required this.stepIndex});

  @override
  Widget build(BuildContext context) {
    const labels = ['Mijoz', 'Sifat', 'Mahsulot'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final lineStep = i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                color: lineStep < stepIndex
                    ? AppColors.primary
                    : AppColors.divider,
              ),
            );
          }
          final idx = i ~/ 2;
          final isActive = idx == stepIndex;
          final isDone = idx < stepIndex;
          return _StepDot(
            label: labels[idx],
            index: idx + 1,
            isActive: isActive,
            isDone: isDone,
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final int index;
  final bool isActive;
  final bool isDone;
  const _StepDot({
    required this.label,
    required this.index,
    required this.isActive,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive || isDone ? AppColors.primary : AppColors.divider;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? AppColors.primary : Colors.transparent,
            border: isDone ? null : Border.all(color: color, width: 2),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isActive ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              ),
        ),
      ],
    );
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
            'Yuborish uchun buyurtma topilmadi',
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${c.itemCount} ta',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
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

// ── Step 2: Qualities ──────────────────────────────────────────────────────────

class _QualitiesList extends StatelessWidget {
  final List<ShipmentImportQualityEntity> qualities;
  final ValueChanged<ShipmentImportQualityEntity> onSelect;
  const _QualitiesList({required this.qualities, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    if (qualities.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Sifat topilmadi',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      itemCount: qualities.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final q = qualities[i];
        return InkWell(
          onTap: () => onSelect(q),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    q.qualityName,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${q.itemCount} ta',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
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

// ── Step 3: Items ──────────────────────────────────────────────────────────────

class _ItemsList extends StatelessWidget {
  final ShipmentImportItemsLoaded state;
  final ValueChanged<int> onToggle;
  final ValueChanged<bool> onToggleAll;

  const _ItemsList({
    required this.state,
    required this.onToggle,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    final items = state.items;

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Yuborish uchun mahsulot topilmadi',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        // Select-all toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
          child: Row(
            children: [
              Text(
                'Jami ${items.length} ta mahsulot',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const Spacer(),
              Switch(
                value: state.allSelected,
                onChanged: onToggleAll,
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Flexible(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (_, i) {
              final item = items[i];
              final isSelected = state.selectedIds.contains(item.orderItemId);
              return InkWell(
                onTap: () => onToggle(item.orderItemId),
                child: _ImportItemTile(item: item, isSelected: isSelected),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ImportItemTile extends StatelessWidget {
  final ShipmentImportItemEntity item;
  final bool isSelected;
  const _ImportItemTile({required this.item, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: isSelected,
              onChanged: null, // handled by parent InkWell
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 10),

          // Thumbnail
          AppThumbnail(imageUrl: item.colorImageUrl, size: 36, borderRadius: 6),
          const SizedBox(width: 10),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.edgeCode != null
                      ? '${item.productName} [${item.edgeCode}]'
                      : item.productName,
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
                    if (item.colorName != null)
                      _Chip(label: item.colorName!),
                    if (item.typeName != null)
                      _Chip(label: item.typeName!),
                    if (item.sizeLabel != null)
                      _Chip(
                        label: item.sizeLabel!,
                        color: AppColors.primary,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Available qty
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.availableQuantity}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
              ),
              Text(
                item.productUnit == 'sqm' ? 'm²' : 'dona',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  const _Chip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
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
