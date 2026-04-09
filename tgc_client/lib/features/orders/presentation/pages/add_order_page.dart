import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/order_form_bloc.dart';
import 'desktop/add_order_desktop_page.dart';
import 'mobile/add_order_mobile_page.dart';

/// Adaptive entry point for the "add order" flow.
/// Wraps both layouts in a single [OrderFormBloc] provider.
class AddOrderPage extends StatelessWidget {
  const AddOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrderFormBloc>(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
            return const AddOrderDesktopPage();
          }
          return const AddOrderMobilePage();
        },
      ),
    );
  }
}
