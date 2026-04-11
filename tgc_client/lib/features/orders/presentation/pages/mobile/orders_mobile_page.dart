import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/order_entity.dart';
import '../../bloc/orders_bloc.dart';
import '../../bloc/orders_event.dart';
import '../../bloc/orders_state.dart';
import '../../widget/order_card.dart';
import '../args/order_detail_args.dart';

class OrdersMobilePage extends StatefulWidget {
  const OrdersMobilePage({super.key});

  @override
  State<OrdersMobilePage> createState() => _OrdersMobilePageState();
}

class _OrdersMobilePageState extends State<OrdersMobilePage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<OrdersBloc>().add(const OrdersNextPageRequested());
    }
  }

  Future<void> _navigateToDetail(OrderEntity order) async {
    await context.pushNamed(
      AppRoutes.orderDetailName,
      extra: OrderDetailArgs(order: order),
    );
  }

  Future<void> _navigateToEdit(OrderEntity order) async {
    final updated = await context.pushNamed(
      AppRoutes.editOrderName,
      extra: order,
    );
    if (updated == true && mounted) {
      context.read<OrdersBloc>().add(const OrdersRefreshRequested());
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
        title: const Text('Buyurtmalar'),
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
                  await context.pushNamed(AppRoutes.addOrderName);
              if (created == true && context.mounted) {
                context
                    .read<OrdersBloc>()
                    .add(const OrdersRefreshRequested());
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
            child: _StatusFilterBar(),
          ),
        ),
      ),
      body: BlocBuilder<OrdersBloc, OrdersState>(
        builder: (context, state) {
          if (state is OrdersLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is OrdersError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context
                        .read<OrdersBloc>()
                        .add(const OrdersRefreshRequested()),
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }
          if (state is OrdersLoaded) {
            if (state.orders.isEmpty) {
              return const Center(child: Text('Buyurtmalar topilmadi.'));
            }
            return RefreshIndicator(
              onRefresh: () async => context
                  .read<OrdersBloc>()
                  .add(const OrdersRefreshRequested()),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount:
                    state.orders.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  if (index >= state.orders.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return OrderCard(
                    order: state.orders[index],
                    onTap: () => _navigateToDetail(state.orders[index]),
                    onEdit: () => _navigateToEdit(state.orders[index]),
                  );
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

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar();

  static const _statusFilters = [
    (label: 'Barchasi', value: null),
    (label: 'Kutilmoqda', value: 'pending'),
    (label: 'Rejalashtirilgan', value: 'planned'),
    (label: 'Ishlab chiqarilmoqda', value: 'on_production'),
    (label: 'Bajarildi', value: 'done'),
    (label: 'Bekor qilindi', value: 'canceled'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersBloc, OrdersState>(
      buildWhen: (prev, curr) =>
          curr is OrdersLoaded || prev is OrdersLoaded,
      builder: (context, state) {
        final activeFilter =
            state is OrdersLoaded ? state.activeStatusFilter : null;
        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _statusFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _statusFilters[index];
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
                  context.read<OrdersBloc>().add(
                        OrdersStatusFilterChanged(filter.value),
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
