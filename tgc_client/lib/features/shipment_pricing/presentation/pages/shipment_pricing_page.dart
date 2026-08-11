import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../clients/domain/entities/client_entity.dart';
import '../../../clients/presentation/bloc/clients_bloc.dart';
import '../../../clients/presentation/bloc/clients_event.dart';
import '../../../clients/presentation/bloc/clients_state.dart';
import '../../../shipments/domain/entities/shipment_entity.dart';
import '../../../shipments/presentation/bloc/shipments_bloc.dart';
import '../../../shipments/presentation/bloc/shipments_event.dart';
import '../../../shipments/presentation/bloc/shipments_state.dart';
import '../../../shipments/presentation/widgets/shipment_filter_bar.dart';
import '../widgets/shipment_pricing_table.dart';

/// The office's way in: every shipment the warehouse has sent out, waiting to
/// be priced.
///
/// The same list as the shipments page, minus everything that creates or
/// changes a shipment — this feature only puts money on documents that
/// already exist, which is why it has its own permission. Tapping a row opens
/// it for pricing.
class ShipmentPricingPage extends StatelessWidget {
  const ShipmentPricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<ShipmentsBloc>()..add(const ShipmentsLoadRequested()),
        ),
        BlocProvider(
          create: (_) => sl<ClientsBloc>()..add(const ClientsLoadRequested()),
        ),
      ],
      child: const _View(),
    );
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _scrollController = ScrollController();

  int? _selectedClientId;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ShipmentsBloc>().add(const ShipmentsNextPageRequested());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilters({int? clientId, DateTimeRange? dateRange}) {
    setState(() {
      _selectedClientId = clientId;
      _selectedDateRange = dateRange;
    });
    context.read<ShipmentsBloc>().add(
          ShipmentsFiltersChanged(clientId: clientId, dateRange: dateRange),
        );
  }

  /// Opens the shipment for pricing, then refreshes: a priced shipment stops
  /// showing "Narxsiz" in the total column.
  Future<void> _openPricing(ShipmentEntity shipment) async {
    await context.pushNamed(
      AppRoutes.shipmentPricingDetailName,
      extra: shipment.id,
    );
    if (!mounted) return;
    context.read<ShipmentsBloc>().add(const ShipmentsRefreshRequested());
  }

  List<ClientEntity> _clientsFromState(ClientsState state) {
    if (state is ClientsLoaded) return state.clients;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Narxlash'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BlocBuilder<ClientsBloc, ClientsState>(
            builder: (context, clientsState) {
              return ShipmentFilterBar(
                clients: _clientsFromState(clientsState),
                selectedClientId: _selectedClientId,
                selectedDateRange: _selectedDateRange,
                onClientChanged: (v) => _applyFilters(
                  clientId: v,
                  dateRange: _selectedDateRange,
                ),
                onDateRangeChanged: (v) => _applyFilters(
                  clientId: _selectedClientId,
                  dateRange: v,
                ),
                onRefresh: () => context
                    .read<ShipmentsBloc>()
                    .add(const ShipmentsRefreshRequested()),
              );
            },
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: BlocBuilder<ShipmentsBloc, ShipmentsState>(
              builder: (context, state) {
                if (state is ShipmentsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is ShipmentsError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context
                              .read<ShipmentsBloc>()
                              .add(const ShipmentsRefreshRequested()),
                          child: const Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is ShipmentsLoaded) {
                  if (state.shipments.isEmpty) return const _EmptyState();

                  return ShipmentPricingTable(
                    shipments: state.shipments,
                    isLoadingMore: state.isLoadingMore,
                    scrollController: _scrollController,
                    onTap: _openPricing,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInvoice02,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Narxlanadigan yuk topilmadi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Filtrlarni o\'zgartiring yoki keyinroq qaytib keling.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
