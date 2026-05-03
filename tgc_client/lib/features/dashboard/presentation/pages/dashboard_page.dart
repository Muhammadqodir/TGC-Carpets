import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/dialogs/confirm_dialog.dart';
import 'package:tgc_client/core/ui/widgets/range_date_picker.dart';
import 'package:tgc_client/core/ui/widgets/static_grid.dart';
import 'package:tgc_client/core/utils/role_permissions.dart';
import 'package:tgc_client/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:tgc_client/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:tgc_client/features/dashboard/presentation/bloc/dashboard_state.dart';
import 'package:tgc_client/features/dashboard/presentation/widgets/dashboard_panel.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/router/app_routes.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<AuthBloc>()),
        BlocProvider(
          create: (_) => sl<DashboardBloc>()
            ..add(DashboardStatsRequested(
              from: RangeDatePicker.currentMonth.start,
              to: RangeDatePicker.currentMonth.end,
            )),
        ),
      ],
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatefulWidget {
  const _DashboardView();

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  late DateTimeRange _range;
  bool _panelVisible = false;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _range = RangeDatePicker.currentMonth;
  }

  void _onRangeChanged(DateTimeRange range) {
    setState(() => _range = range);
    context.read<DashboardBloc>().add(
          DashboardStatsRequested(from: range.start, to: range.end),
        );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Chiqish',
      content: 'Paneldan chiqishni xohlaysizmi?',
      confirmText: 'Chiqish',
      cancelText: 'Bekor qilish',
    );

    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(AuthLogoutRequested());
    }
  }

  Future<void> _refresh() async {
    final completer = Completer<void>();
    final bloc = context.read<DashboardBloc>();
    late StreamSubscription<DashboardState> sub;
    sub = bloc.stream.listen((state) {
      if (state is DashboardStatsLoaded || state is DashboardError) {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      }
    });
    bloc.add(DashboardStatsRequested(from: _range.start, to: _range.end));
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/ic_launcher.png',
              width: 38,
              height: 38,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TGC Carpets'),
                  Text(
                    'Boshqaruv paneli',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: Colors.white),
                  )
                ],
              ),
            )
          ],
        ),
        actions: [
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is! AuthAuthenticated) {
                return const SizedBox.shrink();
              }
              if (state.user.role != 'admin') {
                return const SizedBox.shrink();
              }
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedQrCode,
                      strokeWidth: 2,
                    ),
                    tooltip: 'QR Skanerlash',
                    onPressed: () => context.pushNamed(AppRoutes.scannerName),
                  ),
                  IconButton(
                    icon: HugeIcon(
                      icon: _panelVisible
                          ? HugeIcons.strokeRoundedViewOff
                          : HugeIcons.strokeRoundedView,
                      strokeWidth: 2,
                    ),
                    onPressed: () {
                      setState(() {
                        _panelVisible = !_panelVisible;
                      });
                    },
                  ),
                ],
              );
            },
          ),
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedLogin03,
              strokeWidth: 2,
            ),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Positioned(
          //   child: Container(
          //     height: _scrollOffset,
          //     decoration: BoxDecoration(color: AppColors.primary),
          //   ),
          // ),
          BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthUnauthenticated) {
                context.goNamed(AppRoutes.loginName);
              }
            },
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification is ScrollUpdateNotification) {
                    if (scrollNotification.metrics.pixels <= 0) {
                      setState(() {
                        _scrollOffset = scrollNotification.metrics.pixels * -1;
                      });
                    }
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          if (state is! AuthAuthenticated) {
                            return const SizedBox.shrink();
                          }
                          if (state.user.role != 'admin') {
                            return const SizedBox.shrink();
                          }
                          return DashboardPanel(
                            range: _range,
                            onRangeChanged: _onRangeChanged,
                            visible: _panelVisible,
                          );
                        },
                      ),
                      SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, authState) {
                            final user = authState is AuthAuthenticated
                                ? authState.user
                                : null;

                            if (user == null) {
                              return const SizedBox.shrink();
                            }

                            // Build list of visible cards based on role
                            final visibleCards = <Widget>[];

                            if (RolePermissions.canAccessProducts(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedPrayerRug01,
                                label: 'Mahsulotlar',
                                onTap: () =>
                                    context.pushNamed(AppRoutes.productsName),
                              ));
                            }

                            if (RolePermissions.canAccessOrders(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedAddToList,
                                label: 'Buyurtmalar',
                                onTap: () =>
                                    context.pushNamed(AppRoutes.ordersName),
                              ));
                            }

                            if (RolePermissions.canAccessProduction(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedSetup01,
                                label: 'Ishlab chiqarish',
                                onTap: () =>
                                    context.pushNamed(AppRoutes.productionName),
                              ));
                            }

                            if (RolePermissions.canAccessShipping(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedContainerTruck,
                                label: 'Yuk chiqarish',
                                onTap: () =>
                                    context.pushNamed(AppRoutes.shippingName),
                              ));
                            }

                            if (RolePermissions.canAccessWarehouse(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedWarehouse,
                                label: 'Ombor',
                                onTap: () =>
                                    context.pushNamed(AppRoutes.warehouseName),
                              ));
                            }

                            if (RolePermissions.canAccessStock(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedPackageOpen,
                                label: 'Ombor qoldig\'i',
                                onTap: () => context
                                    .pushNamed(AppRoutes.productsStockName),
                              ));
                            }

                            if (RolePermissions.canAccessClients(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedUserGroup,
                                label: 'Mijozlar',
                                onTap: () =>
                                    context.pushNamed(AppRoutes.clientsName),
                              ));
                            }

                            if (RolePermissions.canAccessDebits(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedBadgeDollarSign,
                                label: 'Debitorlar',
                                onTap: () =>
                                    context.pushNamed(AppRoutes.debitsName),
                              ));
                            }

                            if (RolePermissions.canAccessLabeling(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedReceiptText,
                                label: 'Yorliqlash',
                                onTap: () =>
                                    context.pushNamed(AppRoutes.labelingName),
                              ));
                            }

                            if (RolePermissions.canAccessEmployees(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedUserSettings01,
                                label: 'Hodimlar',
                                onTap: () =>
                                    context.pushNamed(AppRoutes.employeesName),
                              ));
                            }

                            if (RolePermissions.canAccessProductAttributes(
                                user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedPaintBoard,
                                label: 'Atributlar',
                                onTap: () => context
                                    .pushNamed(AppRoutes.productAttributesName),
                              ));
                            }

                            if (RolePermissions.canAccessRawMaterials(user)) {
                              visibleCards.add(_DashboardCard(
                                icon: HugeIcons.strokeRoundedNaturalFood,
                                label: 'Xom ashyo ombori',
                                onTap: () => context
                                    .pushNamed(AppRoutes.rawMaterialsName),
                              ));
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                StaticGrid(
                                  columnCount: 2,
                                  gap: 12,
                                  children: visibleCards,
                                ),
                                SizedBox(height: 12),
                                Card(
                                  child: InkWell(
                                    onTap: () => context
                                        .pushNamed(AppRoutes.settingsName),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 16),
                                      alignment: Alignment.center,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          HugeIcon(
                                            icon: HugeIcons
                                                .strokeRoundedSettings01,
                                            size: 32,
                                            strokeWidth: 2,
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                            'Sozlamalar',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium!
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight.bold),
                                          ))
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              // SizedBox(height: 32),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final dynamic icon;
  final String label;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                size: 48,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
