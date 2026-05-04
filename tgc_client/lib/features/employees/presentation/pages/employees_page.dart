import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/dialogs/confirm_dialog.dart';
import 'package:tgc_client/core/ui/widgets/desktop_status_bar.dart';
import 'package:tgc_client/core/ui/widgets/filter_bar.dart';
import 'package:tgc_client/core/ui/widgets/filter_dropdown.dart';
import 'package:tgc_client/core/ui/widgets/filter_search_field.dart';
import '../bloc/employees_bloc.dart';
import '../bloc/employees_event.dart';
import '../bloc/employees_state.dart';
import '../widgets/employee_table.dart';

/// Employees page with adaptive table (desktop 6 columns, mobile 3 columns).
class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmployeesBloc>()..add(const EmployeesLoadRequested()),
      child: const _EmployeesView(),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmployeesView extends StatefulWidget {
  const _EmployeesView();

  @override
  State<_EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends State<_EmployeesView> {
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
      context.read<EmployeesBloc>().add(const EmployeesNextPageRequested());
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
    return BlocListener<EmployeesBloc, EmployeesState>(
      listenWhen: (prev, curr) =>
          curr is EmployeesLoaded &&
          prev is EmployeesLoaded &&
          curr.actionStatus != prev.actionStatus,
      listener: _onActionStatus,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Hodimlar'),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                final result = await context.pushNamed(AppRoutes.addEmployeeName);
                if (result == true && context.mounted) {
                  context.read<EmployeesBloc>().add(const EmployeesRefreshRequested());
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
            BlocBuilder<EmployeesBloc, EmployeesState>(
              buildWhen: (prev, curr) =>
                  curr is EmployeesLoaded || prev is EmployeesLoaded,
              builder: (context, state) {
                final activeRole = state is EmployeesLoaded ? state.activeRole : null;
                return FilterBar(
                  hasActiveFilters: activeRole != null,
                  onClearFilters: () => context
                      .read<EmployeesBloc>()
                      .add(const EmployeesRoleFilterChanged(null)),
                  onRefresh: () => context
                      .read<EmployeesBloc>()
                      .add(const EmployeesRefreshRequested()),
                  filters: [
                    FilterSearchField(
                      controller: _searchController,
                      onChanged: (v) => context
                          .read<EmployeesBloc>()
                          .add(EmployeesSearchChanged(v)),
                    ),
                    const SizedBox(width: 12),
                    FilterDropdown<String>(
                      hint: 'Rol',
                      value: activeRole,
                      items: const [
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'warehouse_manager', child: Text('Ombor Menejer')),
                        DropdownMenuItem(value: 'sales_manager', child: Text('Savdo Menejer')),
                        DropdownMenuItem(value: 'raw_warehouse_manager', child: Text('Xom Ashyo Menejer')),
                        DropdownMenuItem(value: 'product_manager', child: Text('Mahsulot Menejer')),
                        DropdownMenuItem(value: 'machine_manager', child: Text('Stanok Menejer')),
                        DropdownMenuItem(value: 'production_manager', child: Text('Ishlab Chiqarish Menejer')),
                        DropdownMenuItem(value: 'order_manager', child: Text('Buyurtma Menejer')),
                        DropdownMenuItem(value: 'label_manager', child: Text('Yorliq Menejer')),
                      ],
                      onChanged: (v) => context
                          .read<EmployeesBloc>()
                          .add(EmployeesRoleFilterChanged(v)),
                    ),
                  ],
                );
              },
            ),
            const Divider(height: 1, color: AppColors.divider),

            // ---- Table / states ----
            Expanded(
              child: BlocBuilder<EmployeesBloc, EmployeesState>(
                builder: (context, state) {
                  if (state is EmployeesLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is EmployeesError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.message, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => context
                                .read<EmployeesBloc>()
                                .add(const EmployeesRefreshRequested()),
                            child: const Text('Qayta urinish'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is EmployeesLoaded) {
                    if (state.employees.isEmpty) {
                      return _EmptyState(
                        onAdd: () async {
                          final result = await context.pushNamed(AppRoutes.addEmployeeName);
                          if (result == true && context.mounted) {
                            context
                                .read<EmployeesBloc>()
                                .add(const EmployeesRefreshRequested());
                          }
                        },
                      );
                    }

                    return EmployeeDataTable(
                      employees: state.employees,
                      isLoadingMore: state.isLoadingMore,
                      scrollController: _scrollController,
                      pendingEmployeeId: state.actionStatus is EmployeeActionPending
                          ? (state.actionStatus as EmployeeActionPending).employeeId
                          : null,
                      onEdit: (e) async {
                        final result = await context.pushNamed(
                          AppRoutes.editEmployeeName,
                          extra: e,
                        );
                        if (result == true && context.mounted) {
                          context.read<EmployeesBloc>().add(const EmployeesRefreshRequested());
                        }
                      },
                      onDelete: (e) async {
                        final confirmed = await ConfirmDialog.show(
                          context: context,
                          title: 'O\'chirishni tasdiqlang',
                          content:
                              '"${e.name}" o\'chirilsinmi? Bu amalni ortga qaytarib bo\'lmaydi.',
                        );
                        if (confirmed && context.mounted) {
                          context
                              .read<EmployeesBloc>()
                              .add(EmployeeDeleteRequested(e.id));
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
            BlocBuilder<EmployeesBloc, EmployeesState>(builder: (context, state) {
              final loaded =
                  state is EmployeesLoaded ? state.employees.length : null;
              final total = state is EmployeesLoaded ? state.total : null;
              return DesktopStatusBar(
                child: Text(
                  loaded != null && total != null
                      ? '$loaded / $total ta hodim ko\'rsatilmoqda'
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

  void _onActionStatus(BuildContext context, EmployeesState state) {
    if (state is! EmployeesLoaded) return;
    final status = state.actionStatus;
    final messenger = ScaffoldMessenger.of(context);
    switch (status) {
      case EmployeeActionPending():
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
      case EmployeeActionSuccess(message: final msg):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
      case EmployeeActionFailure(message: final msg):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
      case EmployeeActionIdle():
        break;
    }
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
            'Hodimlar topilmadi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yangi hodim qo\'shing yoki qidiruv soʻzini o\'zgartiring.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Hodim qo\'shish'),
          ),
        ],
      ),
    );
  }
}

