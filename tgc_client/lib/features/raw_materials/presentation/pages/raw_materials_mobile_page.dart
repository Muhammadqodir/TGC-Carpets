import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/appbar_search.dart';
import '../bloc/raw_materials_bloc.dart';
import '../bloc/raw_materials_event.dart';
import '../bloc/raw_materials_state.dart';
import '../widgets/raw_material_card.dart';

/// Mobile list view for Raw Materials.
class RawMaterialsMobilePage extends StatefulWidget {
  const RawMaterialsMobilePage({super.key});

  @override
  State<RawMaterialsMobilePage> createState() => _RawMaterialsMobilePageState();
}

class _RawMaterialsMobilePageState extends State<RawMaterialsMobilePage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String? _selectedType;

  bool get _hasActiveFilters => _selectedType != null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context
          .read<RawMaterialsBloc>()
          .add(const RawMaterialsNextPageRequested());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyTypeFilter(String? type) {
    setState(() => _selectedType = type);
    context.read<RawMaterialsBloc>().add(RawMaterialsTypeFilterChanged(type));
  }

  Future<void> _openFilterSheet(List<String> types) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TypeFilterSheet(
        types: types,
        selectedType: _selectedType,
        onApply: (type) {
          Navigator.of(context).pop();
          _applyTypeFilter(type);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarSearch(
        title: const Text('Xom ashyo ombori'),
        backButton: true,
        searchController: _searchController,
        onChanged: (v) => context
            .read<RawMaterialsBloc>()
            .add(RawMaterialsSearchChanged(v)),
        actions: [
          BlocBuilder<RawMaterialsBloc, RawMaterialsState>(
            builder: (_, state) {
              final types = <String>{};
              if (state is RawMaterialsLoaded) {
                for (final m in state.materials) types.add(m.type);
              }
              return IconButton(
                tooltip: 'Filter',
                icon: Badge(
                  isLabelVisible: _hasActiveFilters,
                  child: const Icon(Icons.filter_list_outlined),
                ),
                onPressed: () => _openFilterSheet(types.toList()..sort()),
              );
            },
          ),
          IconButton(
            tooltip: 'Kirim/Chiqim',
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
              strokeWidth: 2,
            ),
            onPressed: () async {
              final ok = await context.pushNamed(
                AppRoutes.rawMaterialBatchMovementName,
              );
              if (ok == true && context.mounted) {
                context
                    .read<RawMaterialsBloc>()
                    .add(const RawMaterialsRefreshRequested());
              }
            },
          ),
          IconButton(
            tooltip: 'Yangi xom ashyo',
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              strokeWidth: 2,
            ),
            onPressed: () async {
              final ok = await context.pushNamed(AppRoutes.addRawMaterialName);
              if (ok == true && context.mounted) {
                context
                    .read<RawMaterialsBloc>()
                    .add(const RawMaterialsRefreshRequested());
              }
            },
          ),
          IconButton(
            tooltip: 'Yangilash',
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => context
                .read<RawMaterialsBloc>()
                .add(const RawMaterialsRefreshRequested()),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<RawMaterialsBloc, RawMaterialsState>(
        builder: (context, state) {
          if (state is RawMaterialsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is RawMaterialsError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context
                        .read<RawMaterialsBloc>()
                        .add(const RawMaterialsRefreshRequested()),
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          if (state is RawMaterialsLoaded) {
            if (state.materials.isEmpty) {
              return const Center(
                child: Text(
                  'Xom ashyo topilmadi',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => context
                  .read<RawMaterialsBloc>()
                  .add(const RawMaterialsRefreshRequested()),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount:
                    state.materials.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index >= state.materials.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return RawMaterialCard(material: state.materials[index]);
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter Bottom Sheet
// ---------------------------------------------------------------------------

class _TypeFilterSheet extends StatefulWidget {
  const _TypeFilterSheet({
    required this.types,
    required this.selectedType,
    required this.onApply,
  });

  final List<String> types;
  final String? selectedType;
  final ValueChanged<String?> onApply;

  @override
  State<_TypeFilterSheet> createState() => _TypeFilterSheetState();
}

class _TypeFilterSheetState extends State<_TypeFilterSheet> {
  String? _type;

  @override
  void initState() {
    super.initState();
    _type = widget.selectedType;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Filter', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Text('Turi', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: const Text('Barchasi'),
                selected: _type == null,
                onSelected: (_) => setState(() => _type = null),
              ),
              ...widget.types.map(
                (t) => FilterChip(
                  label: Text(t),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onApply(null),
                  child: const Text('Tozalash'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onApply(_type),
                  child: const Text('Qo\'llash'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
