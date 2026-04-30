import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class DesktopStatusBar extends StatelessWidget {
  const DesktopStatusBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      bool isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      if (!isDesktop) return const SizedBox.shrink();
      return Container(
        color: AppColors.primary.withValues(alpha: 0.04),
        child: SafeArea(
          top: false,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            child: child,
          ),
        ),
      );
    });
  }
}
