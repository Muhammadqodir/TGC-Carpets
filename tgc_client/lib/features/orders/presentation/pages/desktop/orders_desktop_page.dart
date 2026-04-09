import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../bloc/orders_bloc.dart';
import '../../bloc/orders_event.dart';
import '../../bloc/orders_state.dart';
import '../../widget/order_table.dart';

class OrdersDesktopPage extends StatefulWidget {
  const OrdersDesktopPage({super.key});

  @override
  State<OrdersDesktopPage> createState() => _OrdersDesktopPageState();
}

class _OrdersDesktopPageState extends State<OrdersDesktopPage> {
  final _scrollController = ScrollController();
  String? _selectedStatus;

  static const _statusFilters = [
    (label: 'Barchasi', value: null),
    (label: 'Kutilmoqda', value: 'pending'),
    (label: 'Ishlab chiqarilmoqda', value: 'on_production'),
    (label: 'Bajarildi', value: 'done'),
    (label: 'Bekor qilindi', value: 'canceled'),
  ];

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Buyurtmalar'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await context.pushNamed(AppRoutes.addOrderName);
              if (created == true && context.mounted) {
                context
                    .read<OrdersBloc>()
                    .add(const OrdersRefreshRequested());
              }
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status filter bar
          Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: _statusFilters.map((f) {
                final isActive = _selectedStatus == f.value;
                return FilterChip(
                  selectedColor: Colors.white,
                  backgroundColor: AppColors.primary,
                  label: Text(
                    f.label,
                    style: TextStyle(
                      color: isActive ? AppColors.primary : Colors.white,
                    ),
                  ),
                  selected: isActive,
                  onSelected: (_) {
                    setState(() => _selectedStatus = f.value);
                    context.read<OrdersBloc>().add(
                          OrdersStatusFilterChanged(f.value),
                        );
                  },
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: BlocBuilder<OrdersBloc, OrdersState>(
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
                    return const Center(
                        child: Text('Buyurtmalar topilmadi.'));
                  }
                  return OrderTable(
                    orders: state.orders,
                    isLoadingMore: state.isLoadingMore,
                    scrollController: _scrollController,
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
