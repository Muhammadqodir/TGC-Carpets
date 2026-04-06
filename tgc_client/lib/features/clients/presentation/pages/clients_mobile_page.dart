import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/widgets/appbar_search.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_bloc.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_event.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_state.dart';
import 'package:tgc_client/features/clients/presentation/widget/client_item.dart';

/// Mobile card-list view for the clients feature.
class ClientsMobilePage extends StatefulWidget {
  const ClientsMobilePage({super.key});

  @override
  State<ClientsMobilePage> createState() => _ClientsMobilePageState();
}

class _ClientsMobilePageState extends State<ClientsMobilePage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ClientsBloc>().add(const ClientsNextPageRequested());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarSearch(
        title: const Text('Mijozlar'),
        searchController: _searchController,
        onChanged: (value) =>
            context.read<ClientsBloc>().add(ClientsSearchChanged(value)),
        backButton: true,
        actions: [
          IconButton(
            onPressed: () => context.pushNamed(AppRoutes.addClientName),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              strokeWidth: 2,
            ),
          ),
        ],
      ),
      body: BlocBuilder<ClientsBloc, ClientsState>(
        builder: (context, state) {
          if (state is ClientsLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ClientsError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context
                        .read<ClientsBloc>()
                        .add(const ClientsRefreshRequested()),
                    child: const Text('Qayta urinish'),
                  ),
                ],
              ),
            );
          }

          if (state is ClientsLoaded) {
            if (state.clients.isEmpty) {
              return const Center(child: Text('Mijozlar topilmadi.'));
            }

            return RefreshIndicator(
              onRefresh: () async => context
                  .read<ClientsBloc>()
                  .add(const ClientsRefreshRequested()),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount:
                    state.clients.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  if (index >= state.clients.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return ClientItem(client: state.clients[index]);
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
