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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<RawMaterialsBloc>().add(const RawMaterialsNextPageRequested());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarSearch(
        title: const Text('Xom ashyo ombori'),
        searchController: _searchController,
        backButton: true,
        onChanged: (q) => context
            .read<RawMaterialsBloc>()
            .add(RawMaterialsSearchChanged(q)),
        actions: [
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
        ],
      ),
      body: Column(
        children: [
          _TypeFilterBar(
            selected: _selectedType,
            onSelected: _applyTypeFilter,
          ),
          Expanded(
            child: BlocBuilder<RawMaterialsBloc, RawMaterialsState>(
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
                    return const Center(child: Text('Xom ashyo topilmadi.'));
                  }

                  return RefreshIndicator(
                    onRefresh: () async => context
                        .read<RawMaterialsBloc>()
                        .add(const RawMaterialsRefreshRequested()),
                    child: ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: state.materials.length +
                          (state.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        if (index >= state.materials.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child:
                                Center(child: CircularProgressIndicator()),
                          );
                        }
                        final material = state.materials[index];
                        return RawMaterialCard(material: material);
                      },
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Type filter chips ──────────────────────────────────────────────────────

class _TypeFilterBar extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _TypeFilterBar({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RawMaterialsBloc, RawMaterialsState>(
      builder: (context, state) {
        // Derive available types from loaded data
        final types = <String>{};
        if (state is RawMaterialsLoaded) {
          for (final m in state.materials) {
            types.add(m.type);
          }
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _Chip(
                label: 'Barchasi',
                selected: selected == null,
                onTap: () => onSelected(null),
              ),
              ...types.map(
                (t) => _Chip(
                  label: t,
                  selected: selected == t,
                  onTap: () => onSelected(t),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
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
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontSize: 12,
        ),
      ),
    );
  }
}
