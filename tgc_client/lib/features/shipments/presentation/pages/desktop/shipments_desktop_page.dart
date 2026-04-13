import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_bloc.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_event.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_state.dart';

import '../../bloc/shipments_bloc.dart';
import '../../bloc/shipments_event.dart';
import '../../bloc/shipments_state.dart';
import '../../widgets/shipment_filter_bar.dart';
import '../../widgets/shipment_table.dart';

/// Desktop view for Shipments — data table layout matching the Warehouse page.
class ShipmentsDesktopPage extends StatelessWidget {
  const ShipmentsDesktopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ClientsBloc>()..add(const ClientsLoadRequested()),
      child: const _DesktopView(),
    );
  }
}

class _DesktopView extends StatefulWidget {
  const _DesktopView();

  @override
  State<_DesktopView> createState() => _DesktopViewState();
}

class _DesktopViewState extends State<_DesktopView> {
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

  void _applyFilters({
    int? clientId,
    DateTimeRange? dateRange,
  }) {
    setState(() {
      _selectedClientId  = clientId;
      _selectedDateRange = dateRange;
    });
    context.read<ShipmentsBloc>().add(
          ShipmentsFiltersChanged(
            clientId:  clientId,
            dateRange: dateRange,
          ),
        );
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
        title: const Text('Yetkazib berish'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter bar
          BlocBuilder<ClientsBloc, ClientsState>(
            builder: (context, clientsState) {
              return ShipmentFilterBar(
                clients:            _clientsFromState(clientsState),
                selectedClientId:   _selectedClientId,
                selectedDateRange:  _selectedDateRange,
                onClientChanged: (v) => _applyFilters(
                  clientId:  v,
                  dateRange: _selectedDateRange,
                ),
                onDateRangeChanged: (v) => _applyFilters(
                  clientId:  _selectedClientId,
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
                  if (state.shipments.isEmpty) {
                    return const _EmptyState();
                  }

                  return ShipmentTable(
                    shipments:        state.shipments,
                    isLoadingMore:    state.isLoadingMore,
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

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Yetkazib berish topilmadi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Filtrlarni o\'zgartiring yoki keyinroq qaytip keling.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
