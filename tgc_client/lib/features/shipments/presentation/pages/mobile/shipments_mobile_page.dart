import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_bloc.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_event.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_state.dart';

import '../../bloc/shipments_bloc.dart';
import '../../bloc/shipments_event.dart';
import '../../bloc/shipments_state.dart';
import '../../widgets/shipment_card.dart';
import '../../widgets/shipment_filter_bar.dart';

class ShipmentsMobilePage extends StatelessWidget {
  const ShipmentsMobilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ClientsBloc>()..add(const ClientsLoadRequested()),
      child: const _MobileView(),
    );
  }
}

class _MobileView extends StatefulWidget {
  const _MobileView();

  @override
  State<_MobileView> createState() => _MobileViewState();
}

class _MobileViewState extends State<_MobileView> {
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
          ShipmentsFiltersChanged(
            clientId: clientId,
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
        title: const Text('Yuk chiqarish'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final result =
                  await context.pushNamed(AppRoutes.addShippingName);
              if (result == true && context.mounted) {
                context
                    .read<ShipmentsBloc>()
                    .add(const ShipmentsRefreshRequested());
              }
            },
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Yangi yuk',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          BlocBuilder<ClientsBloc, ClientsState>(
            builder: (context, clientsState) {
              return ShipmentFilterBar(
                clients: _clientsFromState(clientsState),
                selectedClientId: _selectedClientId,
                selectedDateRange: _selectedDateRange,
                onClientChanged: (v) =>
                    _applyFilters(clientId: v, dateRange: _selectedDateRange),
                onDateRangeChanged: (v) =>
                    _applyFilters(clientId: _selectedClientId, dateRange: v),
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

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: state.shipments.length +
                        (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.shipments.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      return ShipmentCard(
                          shipment: state.shipments[index]);
                    },
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
            icon: HugeIcons.strokeRoundedContainerTruck,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Yuklar topilmadi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
