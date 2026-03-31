import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/widgets/static_grid.dart';
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
    return BlocProvider(
      create: (_) => sl<AuthBloc>()..add(AuthCheckRequested()),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

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
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedLogin03),
            onPressed: () =>
                context.read<AuthBloc>().add(AuthLogoutRequested()),
          ),
        ],
      ),
      body: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthUnauthenticated) {
              context.goNamed(AppRoutes.loginName);
            }
          },
          child: SizedBox(
            height: double.infinity,
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardPanel(),
                  SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StaticGrid(
                          columnCount: 2,
                          gap: 12,
                          children: [
                            _DashboardCard(
                              icon: HugeIcons.strokeRoundedPrayerRug01,
                              label: 'Mahsulotlar',
                              onTap: () =>
                                  context.pushNamed(AppRoutes.productsName),
                            ),
                            _DashboardCard(
                              icon: HugeIcons.strokeRoundedUserGroup,
                              label: 'Mijozlar',
                              onTap: () =>
                                  context.pushNamed(AppRoutes.clientsName),
                            ),
                            _DashboardCard(
                              icon: HugeIcons.strokeRoundedWarehouse,
                              label: 'Ombor',
                              onTap: () =>
                                  context.pushNamed(AppRoutes.warehouseName),
                            ),
                            _DashboardCard(
                              icon: HugeIcons.strokeRoundedAgreement02,
                              label: 'Savdo',
                              onTap: () =>
                                  context.pushNamed(AppRoutes.salesName),
                            ),
                            _DashboardCard(
                              icon: HugeIcons.strokeRoundedUserDollar,
                              label: 'Qarzlar',
                              onTap: () =>
                                  context.pushNamed(AppRoutes.salesName),
                            ),
                            _DashboardCard(
                              icon: HugeIcons.strokeRoundedUserSettings01,
                              label: 'Hodimlar',
                              onTap: () =>
                                  context.pushNamed(AppRoutes.salesName),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Card(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HugeIcon(
                                  icon: HugeIcons.strokeRoundedSettings01,
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
                                      .copyWith(fontWeight: FontWeight.bold),
                                ))
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 32),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )),
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
