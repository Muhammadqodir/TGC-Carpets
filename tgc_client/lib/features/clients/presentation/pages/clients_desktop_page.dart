import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_bloc.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_event.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_state.dart';
import 'package:tgc_client/features/clients/presentation/widget/add_client_modal.dart';
import 'package:tgc_client/features/clients/presentation/widget/client_table.dart';

/// Full desktop view: search bar + scrollable client data table.
class ClientsDesktopPage extends StatefulWidget {
  const ClientsDesktopPage({super.key});

  @override
  State<ClientsDesktopPage> createState() => _ClientsDesktopPageState();
}

class _ClientsDesktopPageState extends State<ClientsDesktopPage> {
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
    return BlocListener<ClientsBloc, ClientsState>(
      listenWhen: (prev, curr) =>
          curr is ClientsLoaded &&
          prev is ClientsLoaded &&
          curr.actionStatus != prev.actionStatus,
      listener: _onActionStatus,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Mijozlar'),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
          actions: [
            IconButton(
              onPressed: () => AddClientModal.show(
                context,
                onClientAdded: () => context
                    .read<ClientsBloc>()
                    .add(const ClientsRefreshRequested()),
              ),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Filter bar ----
          _ClientFilterBar(
            searchController: _searchController,
            onSearchChanged: (v) =>
                context.read<ClientsBloc>().add(ClientsSearchChanged(v)),
            onRefresh: () => context
                .read<ClientsBloc>()
                .add(const ClientsRefreshRequested()),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ---- Table / states ----
          Expanded(
            child: BlocBuilder<ClientsBloc, ClientsState>(
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
                    return _EmptyState(
                      onAdd: () => AddClientModal.show(
                        context,
                        onClientAdded: () => context
                            .read<ClientsBloc>()
                            .add(const ClientsRefreshRequested()),
                      ),
                    );
                  }

                  return ClientDataTable(
                    clients: state.clients,
                    isLoadingMore: state.isLoadingMore,
                    scrollController: _scrollController,
                    pendingClientId: state.actionStatus is ClientActionPending
                        ? (state.actionStatus as ClientActionPending).clientId
                        : null,
                    onEdit: (c) => AddClientModal.show(
                      context,
                      client: c,
                      onClientAdded: () => context
                          .read<ClientsBloc>()
                          .add(const ClientsRefreshRequested()),
                    ),
                    onDelete: (c) => _showDeleteConfirm(context, c),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // ---- Status bar ----
          BlocBuilder<ClientsBloc, ClientsState>(
            builder: (context, state) => _DesktopStatusBar(
              loaded: state is ClientsLoaded ? state.clients.length : null,
              total: state is ClientsLoaded ? state.total : null,
            ),
          ),
        ],
      ),
      ),
    );
  }

  void _onActionStatus(BuildContext context, ClientsState state) {
    if (state is! ClientsLoaded) return;
    final status = state.actionStatus;
    final messenger = ScaffoldMessenger.of(context);
    switch (status) {
      case ClientActionPending():
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Yuklanmoqda...'),
                ],
              ),
              duration: const Duration(seconds: 30),
            ),
          );
      case ClientActionSuccess(message: final msg):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
      case ClientActionFailure(message: final msg):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
      case ClientActionIdle():
        break;
    }
  }

  void _showDeleteConfirm(BuildContext context, ClientEntity client) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('O\'chirishni tasdiqlang'),
        content: Text(
            '"${client.shopName}" o\'chirilsinmi? Bu amalni ortga qaytarib bo\'lmaydi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              context
                  .read<ClientsBloc>()
                  .add(ClientDeleteRequested(client.id));
            },
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar
// ---------------------------------------------------------------------------

class _ClientFilterBar extends StatelessWidget {
  const _ClientFilterBar({
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            height: 38,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Qidirish...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
              ),
            ),
          ),
          const Spacer(),
          // Refresh
          IconButton(
            tooltip: 'Yangilash',
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedReload,
              strokeWidth: 2.5,
            ),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status bar
// ---------------------------------------------------------------------------

class _DesktopStatusBar extends StatelessWidget {
  const _DesktopStatusBar({required this.loaded, required this.total});

  final int? loaded;
  final int? total;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: AppColors.primary.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        loaded != null && total != null
            ? '$loaded / $total ta mijoz ko\'rsatilmoqda'
            : '',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_outline,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Mijozlar topilmadi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yangi mijoz qo\'shing yoki qidiruv soʻzini o\'zgartiring.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Mijoz qo\'shish'),
          ),
        ],
      ),
    );
  }
}
