import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_routes.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../clients/domain/entities/client_entity.dart';
import '../../../domain/entities/order_entity.dart';
import '../../bloc/orders_bloc.dart';
import '../../bloc/orders_event.dart';
import '../../bloc/orders_state.dart';
import '../../widget/order_filter_bar.dart';
import '../../widget/order_table.dart';
import '../args/order_detail_args.dart';

class OrdersDesktopPage extends StatefulWidget {
  const OrdersDesktopPage({super.key});

  @override
  State<OrdersDesktopPage> createState() => _OrdersDesktopPageState();
}

class _OrdersDesktopPageState extends State<OrdersDesktopPage> {
  final _scrollController = ScrollController();

  String? _selectedStatus;
  ClientEntity? _selectedClient;
  DateTimeRange? _selectedDateRange;

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

  void _applyFilters({
    String? status,
    ClientEntity? client,
    DateTimeRange? dateRange,
  }) {
    setState(() {
      _selectedStatus = status;
      _selectedClient = client;
      _selectedDateRange = dateRange;
    });
    context.read<OrdersBloc>().add(
          OrdersFiltersChanged(
            status: status,
            clientId: client?.id,
            dateRange: dateRange,
          ),
        );
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
          // Filter bar
          OrderFilterBar(
            selectedStatus: _selectedStatus,
            selectedClient: _selectedClient,
            selectedDateRange: _selectedDateRange,
            onStatusChanged: (v) => _applyFilters(
              status: v,
              client: _selectedClient,
              dateRange: _selectedDateRange,
            ),
            onClientChanged: (v) => _applyFilters(
              status: _selectedStatus,
              client: v,
              dateRange: _selectedDateRange,
            ),
            onDateRangeChanged: (v) => _applyFilters(
              status: _selectedStatus,
              client: _selectedClient,
              dateRange: v,
            ),
            onRefresh: () =>
                context.read<OrdersBloc>().add(const OrdersRefreshRequested()),
          ),
          const Divider(height: 1, color: AppColors.divider),
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
                    onViewDetail: _navigateToDetail,
                    onEdit: _navigateToEdit,
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
