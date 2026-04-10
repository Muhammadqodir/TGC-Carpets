import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import 'args/order_detail_args.dart';
import 'desktop/order_detail_desktop_page.dart';
import 'mobile/order_detail_mobile_page.dart';

class OrderDetailPage extends StatelessWidget {
  final OrderDetailArgs args;

  const OrderDetailPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return OrderDetailDesktopPage(order: args.order);
        }
        return OrderDetailMobilePage(order: args.order);
      },
    );
  }
}
