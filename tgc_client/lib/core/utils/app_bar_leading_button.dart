import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../ui/dialogs/confirm_dialog.dart';
import 'role_permissions.dart';

/// A helper widget that provides either a back button or logout button
/// depending on whether the user has access to only one feature.
class AppBarLeadingButton extends StatelessWidget {
  const AppBarLeadingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          final hasSingleFeature = 
              RolePermissions.hasSingleFeatureAccess(state.user);
          
          if (hasSingleFeature) {
            // Show logout button for single-feature users
            return IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedLogin03,
                size: 20,
                strokeWidth: 2,
              ),
              tooltip: 'Chiqish',
              onPressed: () => _confirmLogout(context),
            );
          }
        }
        
        // Show back button for multi-feature users
        return IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Chiqish',
      content: 'Tizimdan chiqishni xohlaysizmi?',
      confirmText: 'Chiqish',
      cancelText: 'Bekor qilish',
    );

    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(AuthLogoutRequested());
    }
  }
}
