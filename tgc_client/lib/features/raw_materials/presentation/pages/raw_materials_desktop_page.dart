import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/desktop_status_bar.dart';
import '../bloc/raw_materials_bloc.dart';
import '../bloc/raw_materials_event.dart';
import '../bloc/raw_materials_state.dart';

/// Desktop list view for Raw Materials.
class RawMaterialsDesktopPage extends StatefulWidget {
  const RawMaterialsDesktopPage({super.key});

  @override
  State<RawMaterialsDesktopPage> createState() =>
      _RawMaterialsDesktopPageState();
}

class _RawMaterialsDesktopPageState extends State<RawMaterialsDesktopPage> {
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
      appBar: AppBar(
        title: const Text('Xom ashyo ombori'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(24),
          child: DesktopStatusBar(child: SizedBox.shrink()),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Kirim/Chiqim'),
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
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Yangi xom ashyo'),
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
        children: [
          // ── Filter bar ────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (q) => context
                          .read<RawMaterialsBloc>()
                          .add(RawMaterialsSearchChanged(q)),
                      decoration: InputDecoration(
                        hintText: 'Xom ashyo qidirish...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                BlocBuilder<RawMaterialsBloc, RawMaterialsState>(
                  builder: (_, state) {
                    final types = <String>{};
                    if (state is RawMaterialsLoaded) {
                      for (final m in state.materials) {
                        types.add(m.type);
                      }
                    }
                    return _DesktopTypeFilter(
                      types: types.toList(),
                      selected: _selectedType,
                      onChanged: _applyTypeFilter,
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Table ─────────────────────────────────────────────────────────
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
                        Text(state.message),
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
                    child: _DesktopTable(
                      state: state,
                      scrollController: _scrollController,
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

// ── Desktop data table ─────────────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  final RawMaterialsLoaded state;
  final ScrollController scrollController;

  const _DesktopTable({required this.state, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Nomi')),
          DataColumn(label: Text('Turi')),
          DataColumn(label: Text('Birlik')),
          DataColumn(label: Text('Qoldiq'), numeric: true),
        ],
        rows: [
          for (final m in state.materials)
            DataRow(cells: [
              DataCell(Text(m.name)),
              DataCell(Text(m.type)),
              DataCell(Text(_unitLabel(m.unit))),
              DataCell(
                Text(
                  _formatQty(m.stockQuantity),
                  style: TextStyle(
                    color: m.stockQuantity > 0
                        ? AppColors.success
                        : AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          if (state.isLoadingMore)
            DataRow(cells: [
              const DataCell(
                Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              ...List.generate(3, (_) => const DataCell(SizedBox.shrink())),
            ]),
        ],
      ),
    );
  }

  String _formatQty(double qty) =>
      qty == qty.truncateToDouble()
          ? qty.toInt().toString()
          : qty.toStringAsFixed(2);

  String _unitLabel(String unit) => switch (unit) {
        'sqm'   => 'm²',
        'kg'    => 'kg',
        'piece' => 'dona',
        _       => unit,
      };
}

// ── Desktop type filter dropdown ───────────────────────────────────────────

class _DesktopTypeFilter extends StatelessWidget {
  final List<String> types;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _DesktopTypeFilter({
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: selected,
        hint: const Text('Barcha turlar'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Barcha turlar'),
          ),
          ...types.map(
            (t) => DropdownMenuItem<String?>(
              value: t,
              child: Text(t),
            ),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
