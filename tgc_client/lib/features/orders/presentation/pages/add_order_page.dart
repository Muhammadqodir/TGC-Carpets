import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/order_form_bloc.dart';
import '../widget/order_form_controller.dart';
import 'desktop/add_order_desktop_page.dart';
import 'mobile/add_order_mobile_page.dart';

/// Adaptive entry point for the "add order" flow.
///
/// Owns the [OrderFormController] (form UI state) so it survives
/// mobile ↔ desktop layout switches on resize, and provides a single
/// [OrderFormBloc] to both layout variants.
class AddOrderPage extends StatefulWidget {
  const AddOrderPage({super.key});

  @override
  State<AddOrderPage> createState() => _AddOrderPageState();
}

class _AddOrderPageState extends State<AddOrderPage> {
  late final OrderFormController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = OrderFormController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<OrderFormBloc>(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
            return AddOrderDesktopPage(controller: _ctrl);
          }
          return AddOrderMobilePage(controller: _ctrl);
        },
      ),
    );
  }
}
