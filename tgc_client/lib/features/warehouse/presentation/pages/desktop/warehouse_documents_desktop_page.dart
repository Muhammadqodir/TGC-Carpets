import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/desktop_status_bar.dart';
import 'package:tgc_client/features/employees/domain/entities/employee_entity.dart';
import 'package:tgc_client/features/employees/presentation/bloc/employees_bloc.dart';
import 'package:tgc_client/features/employees/presentation/bloc/employees_event.dart';
import 'package:tgc_client/features/employees/presentation/bloc/employees_state.dart';

import '../../bloc/warehouse_docs_bloc.dart';
import '../../bloc/warehouse_docs_event.dart';
import '../../bloc/warehouse_docs_state.dart';
import '../../widgets/warehouse_document_filter_bar.dart';
import '../../widgets/warehouse_document_table.dart';

/// Desktop view fordocuments with data table layout.
class WarehouseDocumentsDesktopPage extends StatelessWidget {
  const WarehouseDocumentsDesktopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmployeesBloc>()..add(const EmployeesLoadRequested()),
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
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  String? _selectedType;
  int? _selectedUserId;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context
          .read<WarehouseDocsBloc>()
          .add(const WarehouseDocsNextPageRequested());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyFilters({
    String? type,
    int? userId,
    DateTimeRange? dateRange,
  }) {
    setState(() {
      _selectedType = type;
      _selectedUserId = userId;
      _selectedDateRange = dateRange;
    });
    context.read<WarehouseDocsBloc>().add(
          WarehouseDocsFiltersChanged(
            type: type,
            userId: userId,
            dateRange: dateRange,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ombor'),
        titleSpacing: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created =
                  await context.pushNamed(AppRoutes.addWarehouseDocumentName);
              if (created == true && context.mounted) {
                context
                    .read<WarehouseDocsBloc>()
                    .add(const WarehouseDocsRefreshRequested());
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
          BlocBuilder<EmployeesBloc, EmployeesState>(
            builder: (context, employeesState) {
              final employees = _employeesFromState(employeesState);
              return WarehouseDocumentFilterBar(
                searchController: _searchController,
                onSearchChanged: (v) {
                  // TODO: Implement search if needed
                },
                employees: employees,
                selectedType: _selectedType,
                selectedUserId: _selectedUserId,
                selectedDateRange: _selectedDateRange,
                onTypeChanged: (v) => _applyFilters(
                  type: v,
                  userId: _selectedUserId,
                  dateRange: _selectedDateRange,
                ),
                onUserChanged: (v) => _applyFilters(
                  type: _selectedType,
                  userId: v,
                  dateRange: _selectedDateRange,
                ),
                onDateRangeChanged: (v) => _applyFilters(
                  type: _selectedType,
                  userId: _selectedUserId,
                  dateRange: v,
                ),
                onRefresh: () => context
                    .read<WarehouseDocsBloc>()
                    .add(const WarehouseDocsRefreshRequested()),
              );
            },
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: BlocBuilder<WarehouseDocsBloc, WarehouseDocsState>(
              builder: (context, state) {
                if (state is WarehouseDocsLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state is WarehouseDocsError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.message, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => context
                              .read<WarehouseDocsBloc>()
                              .add(const WarehouseDocsRefreshRequested()),
                          child: const Text('Qayta urinish'),
                        ),
                      ],
                    ),
                  );
                }

                if (state is WarehouseDocsLoaded) {
                  if (state.documents.isEmpty) {
                    return _EmptyState(
                      onAddDocument: () async {
                        final created = await context
                            .pushNamed(AppRoutes.addWarehouseDocumentName);
                        if (created == true && context.mounted) {
                          context
                              .read<WarehouseDocsBloc>()
                              .add(const WarehouseDocsRefreshRequested());
                        }
                      },
                    );
                  }

                  return WarehouseDocumentTable(
                    documents: state.documents,
                    isLoadingMore: state.isLoadingMore,
                    scrollController: _scrollController,
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          BlocBuilder<WarehouseDocsBloc, WarehouseDocsState>(
            builder: (context, state) {
              final loaded =
                  state is WarehouseDocsLoaded ? state.documents.length : null;
              return DesktopStatusBar(
                child: Text(
                  loaded != null
                      ? '$loaded ta hujjat ko\'rsatilmoqda'
                      : '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<EmployeeEntity> _employeesFromState(EmployeesState state) {
    return switch (state) {
      EmployeesLoaded r => r.employees,
      _ => const [],
    };
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddDocument});

  final VoidCallback onAddDocument;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 56,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Hujjatlar topilmadi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yangi hujjat qo\'shing yoki filtrlarni o\'zgartiring.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAddDocument,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Hujjat qo\'shish'),
          ),
        ],
      ),
    );
  }
}
