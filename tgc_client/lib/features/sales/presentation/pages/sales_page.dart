import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:tgc_client/features/sales/presentation/bloc/sales_event.dart';
import 'package:tgc_client/features/sales/presentation/bloc/sales_state.dart';
import 'package:tgc_client/features/sales/presentation/widget/sale_card.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<SalesBloc>()..add(const SalesLoadRequested()),
      child: const _SalesView(),
    );
  }
}

class _SalesView extends StatefulWidget {
  const _SalesView();

  @override
  State<_SalesView> createState() => _SalesViewState();
}

class _SalesViewState extends State<_SalesView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SalesBloc>().add(const SalesNextPageRequested());
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
        title: const Text('Sotuvlar'),
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
              final result = await context.pushNamed(AppRoutes.addSaleName);
              if (result == true && context.mounted) {
                context.read<SalesBloc>().add(const SalesRefreshRequested());
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
            child: _FilterBar(),
          ),
        ),
      ),
      body: BlocBuilder<SalesBloc, SalesState>(
        builder: (context, state) {
          if (state is SalesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is SalesError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context
                        .read<SalesBloc>()
                        .add(const SalesRefreshRequested()),
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          if (state is SalesLoaded) {
            if (state.sales.isEmpty) {
              return const Center(child: Text('Sotuvlar topilmadi.'));
            }

            return RefreshIndicator(
              onRefresh: () async =>
                  context.read<SalesBloc>().add(const SalesRefreshRequested()),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: state.sales.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  if (index >= state.sales.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return SaleCard(sale: state.sales[index]);
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

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  static const _filters = [
    (label: 'Barchasi', value: null),
    (label: 'Kutilmoqda', value: 'pending'),
    (label: 'Qisman', value: 'partial'),
    (label: 'To\'langan', value: 'paid'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SalesBloc, SalesState>(
      buildWhen: (prev, curr) => curr is SalesLoaded || prev is SalesLoaded,
      builder: (context, state) {
        final activeFilter = state is SalesLoaded ? state.activeFilter : null;

        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
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
                  context.read<SalesBloc>().add(
                        SalesFilterChanged(paymentStatus: filter.value),
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
