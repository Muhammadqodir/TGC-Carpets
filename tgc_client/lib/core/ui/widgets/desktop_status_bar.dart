import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class DesktopStatusBar extends StatelessWidget {
  const DesktopStatusBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      color: AppColors.primary.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: child,
    );
  }
}
