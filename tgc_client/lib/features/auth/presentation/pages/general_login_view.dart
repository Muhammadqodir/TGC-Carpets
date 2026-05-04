
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/ui/pages/settings_page.dart';
import 'package:tgc_client/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:tgc_client/features/auth/presentation/bloc/auth_state.dart';
import 'package:tgc_client/features/auth/presentation/widgets/login_form.dart';

class GeneralLoginView extends StatelessWidget {
  const GeneralLoginView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Navigate to splash which will handle role-based routing
            context.goNamed(AppRoutes.splashName);
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        child: SafeArea(
          child: Stack(children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Image.asset(
                        'assets/ic_launcher.png',
                        width: 120,
                        height: 120,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'TGC Carpets',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Boshqaruv paneliga kirish',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 40),
                      const LoginForm(),
                      const SizedBox(height: 75),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton.filled(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CoreSettingsPage(),
                    ),
                  );
                },
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedSettings01,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
