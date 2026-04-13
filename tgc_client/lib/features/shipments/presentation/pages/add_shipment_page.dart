import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/shipment_form_bloc.dart';
import '../widgets/shipment_form_controller.dart';
import 'desktop/add_shipment_desktop_page.dart';

/// Adaptive entry point for the "add shipment" flow.
///
/// Owns the [ShipmentFormController] so state survives mobile ↔ desktop
/// layout switches. Provides the [ShipmentFormBloc] to the subtree.
class AddShipmentPage extends StatefulWidget {
  const AddShipmentPage({super.key});

  @override
  State<AddShipmentPage> createState() => _AddShipmentPageState();
}

class _AddShipmentPageState extends State<AddShipmentPage> {
  late final ShipmentFormController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ShipmentFormController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ShipmentFormBloc>(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // For now only the desktop layout exists; mobile can be added later.
          if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
            return AddShipmentDesktopPage(controller: _ctrl);
          }
          // Fallback — reuse desktop page for smaller screens until a dedicated
          // mobile layout is built.
          return AddShipmentDesktopPage(controller: _ctrl);
        },
      ),
    );
  }
}
