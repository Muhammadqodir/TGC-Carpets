import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/desktop_status_bar.dart';
import '../bloc/raw_materials_bloc.dart';
import '../bloc/raw_materials_event.dart';
import '../bloc/raw_materials_state.dart';
import '../widgets/raw_material_data_table.dart';
import '../widgets/raw_material_filter_bar.dart';

/// Raw materials page with adaptive table layout.
class RawMaterialsPage extends StatelessWidget {
  const RawMaterialsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<RawMaterialsBloc>()..add(const RawMaterialsLoadRequested()),
      child: const _RawMaterialsView(),
    );
  }
}

// ---------------------------------------------------------------------------

class _RawMaterialsView extends StatefulWidget {
  const _RawMaterialsView();

  @override
  State<_RawMaterialsView> createState() => _RawMaterialsViewState();
}

class _RawMaterialsViewState extends State<_RawMaterialsView> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xom ashyo ombori'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
              strokeWidth: 3,
              size: 20,
              color: AppColors.background,
            ),
            tooltip: "Ombor harakatlari",
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
          const SizedBox(width: 8),
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              strokeWidth: 3,
              size: 20,
            ),
            tooltip: "Yangi xom ashyo",
            onPressed: () async {
              final ok = await context.pushNamed(AppRoutes.addRawMaterialName);
              if (ok == true && context.mounted) {
                context
                    .read<RawMaterialsBloc>()
                    .add(const RawMaterialsRefreshRequested());
              }
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Filter bar ──────────────────────────────────────────────────
          BlocBuilder<RawMaterialsBloc, RawMaterialsState>(
            builder: (_, state) {
              final types = <String>{};
              if (state is RawMaterialsLoaded) {
                for (final m in state.materials) {
                  types.add(m.type);
                }
              }
              return RawMaterialFilterBar(
                types: types.toList()..sort(),
                selectedType: _selectedType,
                onTypeChanged: _applyTypeFilter,
                searchController: _searchController,
                onSearchChanged: (v) => context
                    .read<RawMaterialsBloc>()
                    .add(RawMaterialsSearchChanged(v)),
                onRefresh: () => context
                    .read<RawMaterialsBloc>()
                    .add(const RawMaterialsRefreshRequested()),
              );
            },
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ── Table / states ──────────────────────────────────────────────
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
                    return const Center(
                      child: Text(
                        'Xom ashyo topilmadi',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return RawMaterialDataTable(
                    materials: state.materials,
                    isLoadingMore: state.isLoadingMore,
                    scrollController: _scrollController,
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // ── Status bar ──────────────────────────────────────────────────
          BlocBuilder<RawMaterialsBloc, RawMaterialsState>(
            builder: (context, state) {
              final count =
                  state is RawMaterialsLoaded ? state.materials.length : null;
              return DesktopStatusBar(
                child: Text(
                  count != null ? '$count ta xom ashyo ko\'rsatilmoqda' : '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
