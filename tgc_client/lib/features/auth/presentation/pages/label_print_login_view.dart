import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/router/app_routes.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/pages/settings_page.dart';
import 'package:tgc_client/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:tgc_client/features/auth/domain/entities/user_entity.dart';
import 'package:tgc_client/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:tgc_client/features/auth/presentation/bloc/auth_event.dart';
import 'package:tgc_client/features/auth/presentation/bloc/auth_state.dart';
import 'package:tgc_client/features/auth/presentation/widgets/otp_pad.dart';
import 'package:tgc_client/features/auth/presentation/widgets/user_item.dart';

class LabelLoginView extends StatefulWidget {
  const LabelLoginView({super.key});

  @override
  State<LabelLoginView> createState() => _LabelLoginViewState();
}

class _LabelLoginViewState extends State<LabelLoginView> {
  List<UserEntity> _labelUsers = [];
  UserEntity? _selectedUser;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLabelUsers();
  }

  Future<void> _loadLabelUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final datasource = sl<AuthRemoteDataSource>();
      final users = await datasource.getLabelManagers();
      setState(() {
        _labelUsers = users;
        _isLoading = false;
        // Auto-select first user if available
        if (_labelUsers.isNotEmpty) {
          _selectedUser = _labelUsers.first;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Foydalanuvchilarni yuklashda xatolik: $e';
      });
    }
  }

  void _handleOTPComplete(String password) {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iltimos, foydalanuvchini tanlang'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Trigger login
    context.read<AuthBloc>().add(
          AuthLoginRequested(
            email: _selectedUser!.email,
            password: password,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
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
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/ic_launcher.png',
                              width: 120,
                              height: 120,
                            ),
                            const SizedBox(width: 24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TGC Carpets',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Yorliq chop etish tizimi',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left side: User list
                            Expanded(
                              child: _buildUserList(),
                            ),
                            const SizedBox(width: 40),
                            // Right side: OTP pad
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  OTPPad(onComplete: _handleOTPComplete),
                                  const SizedBox(height: 75),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedSettings01,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadLabelUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    if (_labelUsers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Yorliq menejer foydalanuvchilari topilmadi',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Text(
            'Foydalanuvchini tanlang:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              children: _labelUsers.map((user) {
                return UserItem(
                  isSelected: _selectedUser?.id == user.id,
                  user: user,
                  onTap: () {
                    setState(() {
                      _selectedUser = user;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
