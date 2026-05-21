import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../clients/domain/entities/client_entity.dart';
import '../../data/services/order_form_draft_service.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/usecases/get_order_usecase.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import '../bloc/orders_state.dart';
import '../widgets/order_filter_bar.dart';
import '../widgets/order_table.dart';
import 'args/order_detail_args.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrdersBloc>()..add(const OrdersLoadRequested()),
      child: const _OrdersContent(),
    );
  }
}

class _OrdersContent extends StatefulWidget {
  const _OrdersContent();

  @override
  State<_OrdersContent> createState() => _OrdersContentState();
}

class _OrdersContentState extends State<_OrdersContent> {
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

  Future<void> _deleteOrder(OrderEntity order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buyurtmani o\'chirish'),
        content: Text(
            '#${order.id} buyurtmani o\'chirishni tasdiqlaysizmi? Bu amalni qaytarib bo\'lmaydi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<OrdersBloc>().add(OrderDeleted(order.id));
    }
  }

  Future<void> _navigateToEdit(OrderEntity order) async {
    // The list API returns lightweight items (no product/color/type data).
    // Fetch the full order detail so EditOrderFormController can seed the matrix.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Yuklanmoqda...'),
          ],
        ),
      ),
    );

    final result = await sl<GetOrderUseCase>().call(order.id);

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Buyurtmani yuklashda xatolik: ${failure.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      (fullOrder) async {
        final updated = await context.pushNamed(
          AppRoutes.editOrderName,
          extra: fullOrder,
        );
        if (updated == true && mounted) {
          context.read<OrdersBloc>().add(const OrdersRefreshRequested());
        }
      },
    );
  }

  Future<void> _copyOrder(OrderEntity order) async {
    // Show a non-dismissible progress dialog while fetching the full order.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Nusxa tayyorlanmoqda...'),
          ],
        ),
      ),
    );

    print('DEBUG _copyOrder: fetching full order id=${order.id}');
    final result = await sl<GetOrderUseCase>().call(order.id);

    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    result.fold(
      (failure) {
        print('DEBUG _copyOrder: fetch failed: $failure');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Buyurtmani yuklashda xatolik: ${failure.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      (fullOrder) async {
        print('DEBUG _copyOrder: fullOrder.items.length=${fullOrder.items.length}');
        for (int i = 0; i < fullOrder.items.length; i++) {
          final item = fullOrder.items[i];
          print('DEBUG _copyOrder: item[$i] productName=${item.productName}, productColorId=${item.productColorId}, sizeId=${item.productSizeId}, qty=${item.quantity}');
        }
        final prefs = await SharedPreferences.getInstance();
        final draftService = OrderFormDraftService(prefs);
        await draftService.clear();
        print('DEBUG _copyOrder: draft cleared');
        await draftService.saveFromOrderItems(fullOrder.items);
        print('DEBUG _copyOrder: draft saved, navigating to addOrder');
        if (!mounted) return;
        final created = await context.pushNamed(AppRoutes.addOrderName);
        if (created == true && mounted) {
          context.read<OrdersBloc>().add(const OrdersRefreshRequested());
        }
      },
    );
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
      body: SafeArea(
        child: Column(
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
                      onDelete: _deleteOrder,
                      onCopy: _copyOrder,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
