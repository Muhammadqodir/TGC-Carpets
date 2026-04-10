import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/order_entity.dart';
import '../bloc/order_form_bloc.dart';
import '../widget/edit_order_form_controller.dart';
import '../widget/order_form_controller.dart';
import 'desktop/add_order_desktop_page.dart';
import 'mobile/add_order_mobile_page.dart';

/// Unified adaptive entrypoint for both the "add order" and "edit order" flows.
///
/// Pass [order] to enter edit mode (pre-fills form, submits an update).
/// Omit [order] (or pass null) to enter add mode (empty form, creates new).
class OrderFormPage extends StatefulWidget {
  const OrderFormPage({super.key, this.order});

  /// When non-null the form operates in edit mode.
  final OrderEntity? order;

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends State<OrderFormPage> {
  late final OrderFormController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.order != null
        ? EditOrderFormController(initialItems: widget.order!.items)
        : OrderFormController();
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
            return AddOrderDesktopPage(
              controller: _ctrl,
              initialOrder: widget.order,
            );
          }
          return AddOrderMobilePage(
            controller: _ctrl,
            initialOrder: widget.order,
          );
        },
      ),
    );
  }
}
