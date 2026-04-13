import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import '../bloc/employees_bloc.dart';
import '../bloc/employees_event.dart';
import '../bloc/employees_state.dart';
import '../widgets/employee_item.dart';

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

class _EmployeesView extends StatefulWidget {
  const _EmployeesView();

  @override
  State<_EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends State<_EmployeesView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSearching = false;
  final _searchFocus = FocusNode();

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
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _isSearching = !_isSearching);
    if (!_isSearching) {
      _searchController.clear();
      _searchFocus.unfocus();
      context.read<EmployeesBloc>().add(const EmployeesSearchChanged(''));
    } else {
      _searchFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                onChanged: (v) =>
                    context.read<EmployeesBloc>().add(EmployeesSearchChanged(v)),
                cursorColor: Colors.white,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white),
                decoration: const InputDecoration(
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  hintText: 'Qidirish...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
              )
            : const Text('Hodimlar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: HugeIcon(
              icon: _isSearching
                  ? HugeIcons.strokeRoundedCancel01
                  : HugeIcons.strokeRoundedSearch01,
              strokeWidth: 2,
            ),
          ),
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
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: _RoleFilterBar(),
          ),
        ),
      ),
      body: BlocBuilder<EmployeesBloc, EmployeesState>(
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
              return const Center(child: Text('Hodimlar topilmadi.'));
            }

            return RefreshIndicator(
              onRefresh: () async =>
                  context.read<EmployeesBloc>().add(const EmployeesRefreshRequested()),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: state.employees.length + (state.isLoadingMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  if (index >= state.employees.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return EmployeeItem(employee: state.employees[index]);
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

class _RoleFilterBar extends StatelessWidget {
  const _RoleFilterBar();

  static const _filters = [
    (label: 'Barchasi', value: null),
    (label: 'Admin', value: 'admin'),
    (label: 'Ombor', value: 'warehouse'),
    (label: 'Sotuvchi', value: 'seller'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      buildWhen: (prev, curr) =>
          curr is EmployeesLoaded || prev is EmployeesLoaded,
      builder: (context, state) {
        final activeRole = state is EmployeesLoaded ? state.activeRole : null;

        return SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = _filters[index];
              final isActive = activeRole == filter.value;
              return FilterChip(
                selectedColor: Colors.white,
                backgroundColor: AppColors.primary,
                label: Text(
                  filter.label,
                  style: TextStyle(
                    color: isActive ? AppColors.primary : Colors.white,
                  ),
                ),
                selected: isActive,
                onSelected: (_) {
                  context
                      .read<EmployeesBloc>()
                      .add(EmployeesRoleFilterChanged(filter.value));
                },
              );
            },
          ),
        );
      },
    );
  }
}
