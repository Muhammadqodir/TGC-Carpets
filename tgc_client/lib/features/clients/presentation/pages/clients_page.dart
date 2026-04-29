import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/dialogs/confirm_dialog.dart';
import 'package:tgc_client/core/ui/widgets/desktop_status_bar.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_bloc.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_event.dart';
import 'package:tgc_client/features/clients/presentation/bloc/clients_state.dart';
import 'package:tgc_client/features/clients/presentation/widgets/client_table.dart';

/// Clients page with adaptive table (desktop 7 columns, mobile 3 columns).
class ClientsPage extends StatelessWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ClientsBloc>()..add(const ClientsLoadRequested()),
      child: const _ClientsView(),
    );
  }
}

// ---------------------------------------------------------------------------

class _ClientsView extends StatefulWidget {
  const _ClientsView();

  @override
  State<_ClientsView> createState() => _ClientsViewState();
}

class _ClientsViewState extends State<_ClientsView> {
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
              onPressed: () async {
                await context.pushNamed(AppRoutes.addClientName);
                if (context.mounted) {
                  context.read<ClientsBloc>().add(const ClientsRefreshRequested());
                }
              },
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
                        onAdd: () async {
                          await context.pushNamed(AppRoutes.addClientName);
                          if (context.mounted) {
                            context
                                .read<ClientsBloc>()
                                .add(const ClientsRefreshRequested());
                          }
                        },
                      );
                    }

                    return ClientDataTable(
                      clients: state.clients,
                      isLoadingMore: state.isLoadingMore,
                      scrollController: _scrollController,
                      pendingClientId: state.actionStatus is ClientActionPending
                          ? (state.actionStatus as ClientActionPending).clientId
                          : null,
                      onEdit: (c) async {
                        await context.pushNamed(
                          AppRoutes.addClientName,
                          extra: c,
                        );
                        if (context.mounted) {
                          context
                              .read<ClientsBloc>()
                              .add(const ClientsRefreshRequested());
                        }
                      },
                      onDelete: (c) async {
                        final confirmed = await ConfirmDialog.show(
                          context: context,
                          title: 'O\'chirishni tasdiqlang',
                          content:
                              '"${c.shopName}" o\'chirilsinmi? Bu amalni ortga qaytarib bo\'lmaydi.',
                        );
                        if (confirmed && context.mounted) {
                          context
                              .read<ClientsBloc>()
                              .add(ClientDeleteRequested(c.id));
                        }
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),

            // ---- Status bar ----
            BlocBuilder<ClientsBloc, ClientsState>(builder: (context, state) {
              final loaded =
                  state is ClientsLoaded ? state.clients.length : null;
              final total = state is ClientsLoaded ? state.total : null;
              return DesktopStatusBar(
                child: Text(
                  loaded != null && total != null
                      ? '$loaded / $total ta mijoz ko\'rsatilmoqda'
                      : '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              );
            }),
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



