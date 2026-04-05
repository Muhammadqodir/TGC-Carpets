import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../bloc/warehouse_docs_bloc.dart';
import '../bloc/warehouse_docs_event.dart';
import '../bloc/warehouse_docs_state.dart';
import '../widget/warehouse_document_card.dart';

class WarehousePage extends StatelessWidget {
  const WarehousePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<WarehouseDocsBloc>()..add(const WarehouseDocsLoadRequested()),
      child: const _WarehouseView(),
    );
  }
}

class _WarehouseView extends StatefulWidget {
  const _WarehouseView();

  @override
  State<_WarehouseView> createState() => _WarehouseViewState();
}

class _WarehouseViewState extends State<_WarehouseView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context
          .read<WarehouseDocsBloc>()
          .add(const WarehouseDocsNextPageRequested());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ombor'),
        titleSpacing: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            strokeWidth: 2,
          ),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final created =
                  await context.pushNamed(AppRoutes.addWarehouseDocumentName);
              if (created == true && context.mounted) {
                context
                    .read<WarehouseDocsBloc>()
                    .add(const WarehouseDocsRefreshRequested());
              }
            },
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              strokeWidth: 2,
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: _TypeFilterBar(),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<WarehouseDocsBloc, WarehouseDocsState>(
              builder: (context, state) {
                if (state is WarehouseDocsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is WarehouseDocsError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context
                              .read<WarehouseDocsBloc>()
                              .add(const WarehouseDocsRefreshRequested()),
                          child: const Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is WarehouseDocsLoaded) {
                  if (state.documents.isEmpty) {
                    return const Center(child: Text('Hujjatlar topilmadi.'));
                  }

                  return RefreshIndicator(
                    onRefresh: () async => context
                        .read<WarehouseDocsBloc>()
                        .add(const WarehouseDocsRefreshRequested()),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.documents.length +
                          (state.isLoadingMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        if (index >= state.documents.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        return WarehouseDocumentCard(
                          document: state.documents[index],
                        );
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

class _TypeFilterBar extends StatelessWidget {
  const _TypeFilterBar();

  static const _typeFilters = [
    (label: 'Barchasi', value: null),
    (label: 'Kirim', value: 'in'),
    (label: 'Chiqim', value: 'out'),
    (label: 'Qaytish', value: 'return'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WarehouseDocsBloc, WarehouseDocsState>(
      buildWhen: (prev, curr) =>
          curr is WarehouseDocsLoaded || prev is WarehouseDocsLoaded,
      builder: (context, state) {
        final activeFilter =
            state is WarehouseDocsLoaded ? state.activeTypeFilter : null;

        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _typeFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _typeFilters[index];
              final isActive = activeFilter == filter.value;
              return FilterChip(
                selectedColor: Colors.white,
                backgroundColor: AppColors.primary,
                label: Text(
                  filter.label,
                  style: TextStyle(
                    color: isActive ? AppColors.primary : Colors.white,
                  ),
                ),
                selected: isActive,
                onSelected: (_) {
                  context.read<WarehouseDocsBloc>().add(
                        WarehouseDocsTypeFilterChanged(filter.value),
                      );
                },
              );
            },
          ),
        );
      },
    );
  }
}
