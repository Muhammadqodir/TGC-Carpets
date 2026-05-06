import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import '../../../../core/router/app_routes.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../app_updates/domain/entities/app_release_entity.dart';
import '../../../app_updates/presentation/bloc/app_update_bloc.dart';
import '../../../app_updates/presentation/bloc/app_update_event.dart';
import '../../../app_updates/presentation/bloc/app_update_state.dart';
import '../../../app_updates/presentation/widgets/update_dialog.dart';

/// Splash page that serves as the entry point of the app.
///
/// Responsibilities:
/// - Check for app updates (Android / Windows only)
/// - Check authentication status
/// - Navigate to appropriate destination:
///   * If not authenticated -> Login page
///   * If authenticated     -> Dashboard
///
/// Both checks run in parallel. Navigation is deferred until both complete
/// (or the 5-second update-check timeout fires). If an update is available
/// the update dialog is shown before navigating.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String _version = '';

  // ── Coordination state ────────────────────────────────────────────────────
  String? _destRoute;
  bool _updateChecked = false;
  bool _navigated = false;
  AppReleaseEntity? _pendingRelease;
  Timer? _updateCheckTimer;

  bool get _updateSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isWindows);

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;

    setState(() => _version = 'v${packageInfo.version}');

    // Fire auth check
    context.read<AuthBloc>().add(AuthCheckRequested());

    // Fire update check on supported platforms
    if (_updateSupported) {
      final buildCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      final platform = Platform.isAndroid ? 'android' : 'windows';
      context.read<AppUpdateBloc>().add(
            CheckForUpdateRequested(
              currentBuildCode: buildCode,
              platform: platform,
            ),
          );
      // Safety timeout: if the check takes too long, proceed without it
      _updateCheckTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) _onUpdateChecked(null);
      });
    } else {
      _updateChecked = true;
    }
  }

  void _onAuthResult(String routeName) {
    _destRoute = routeName;
    _maybeNavigate();
  }

  void _onUpdateChecked(AppReleaseEntity? release) {
    if (_updateChecked) return; // prevent double-call from timer + listener
    _updateCheckTimer?.cancel();
    _pendingRelease = release;
    _updateChecked = true;
    _maybeNavigate();
  }

  Future<void> _maybeNavigate() async {
    if (_navigated || _destRoute == null || !_updateChecked) return;
    if (!mounted) return;
    _navigated = true;

    if (_pendingRelease != null) {
      await showUpdateDialog(
        context,
        release: _pendingRelease!,
        bloc: context.read<AppUpdateBloc>(),
      );
      if (!mounted) return;
      // Required update: user must install — do not navigate
      if (_pendingRelease!.isRequired) return;
    }

    if (mounted) context.goNamed(_destRoute!);
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthUnauthenticated || state is AuthFailure) {
              _onAuthResult(AppRoutes.loginName);
            } else if (state is AuthAuthenticated) {
              _onAuthResult(AppRoutes.dashboardName);
            }
          },
        ),
        BlocListener<AppUpdateBloc, AppUpdateState>(
          listener: (context, state) {
            if (state is AppUpdateAvailable) {
              _onUpdateChecked(state.release);
            } else if (state is AppUpdateNotAvailable ||
                state is AppUpdateError) {
              _onUpdateChecked(null);
            }
          },
        ),
      ],
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            // gradient: LinearGradient(
            //   begin: Alignment.topCenter,
            //   end: Alignment.bottomCenter,
            //   colors: [
            //     Theme.of(context).colorScheme.primary,
            //     Theme.of(context).colorScheme.primary.withOpacity(0.8),
            //   ],
            // ),
            color: AppColors.primary
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/ic_launcher.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 24),
                // App Name
                Text(
                  'TGC Carpets',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ishlab chiqarish boshqaruv tizimi',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
                const SizedBox(height: 48),
                // Loading Indicator
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                const SizedBox(height: 24),
                // Version
                if (_version.isNotEmpty)
                  Text(
                    _version,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.7),
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
