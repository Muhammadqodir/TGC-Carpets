import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/orders_bloc.dart';
import '../bloc/orders_event.dart';
import 'desktop/orders_desktop_page.dart';
import 'mobile/orders_mobile_page.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrdersBloc>()..add(const OrdersLoadRequested()),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
            return const OrdersDesktopPage();
          }
          return const OrdersMobilePage();
        },
      ),
    );
  }
}
