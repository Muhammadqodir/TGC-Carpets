import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/di/injection.dart';
import '../../../app_updates/presentation/bloc/app_update_bloc.dart';
import '../../../app_updates/presentation/bloc/app_update_event.dart';
import '../../../app_updates/presentation/bloc/app_update_state.dart';
import '../../../app_updates/presentation/widgets/update_dialog.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SettingsBloc>()),
        BlocProvider(create: (_) => sl<AppUpdateBloc>()),
      ],
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatefulWidget {
  const _SettingsView();

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _currentObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;

  String _version = '';
  String _buildNumber = '';

  // Only show update feature on supported platforms
  bool get _updateSupported => Platform.isAndroid || Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<SettingsBloc>().add(
          ChangePasswordSubmitted(
            currentPassword: _currentPasswordCtrl.text,
            newPassword: _newPasswordCtrl.text,
          ),
        );
  }

  void _checkForUpdates() {
    final buildCode = int.tryParse(_buildNumber) ?? 0;
    final platform  = Platform.isAndroid ? 'android' : 'windows';

    context.read<AppUpdateBloc>().add(
          CheckForUpdateRequested(
            currentBuildCode: buildCode,
            platform: platform,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sozlamalar')),
      body: BlocListener<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            _currentPasswordCtrl.clear();
            _newPasswordCtrl.clear();
            _confirmPasswordCtrl.clear();
            _formKey.currentState?.reset();
          } else if (state is SettingsFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        child: BlocListener<AppUpdateBloc, AppUpdateState>(
          listener: (context, state) {
            if (state is AppUpdateAvailable) {
              showUpdateDialog(
                context,
                release: state.release,
                bloc: context.read<AppUpdateBloc>(),
              );
            } else if (state is AppUpdateNotAvailable) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ilova allaqachon yangilangan.')),
              );
            } else if (state is AppUpdateError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Password change ────────────────────────────────────
                  _SectionHeader('Parolni o\'zgartirish'),
                  const SizedBox(height: 16),
                  _PasswordField(
                    controller: _currentPasswordCtrl,
                    label: 'Joriy parol',
                    obscure: _currentObscure,
                    onToggle: () =>
                        setState(() => _currentObscure = !_currentObscure),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Joriy parolni kiriting'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: _newPasswordCtrl,
                    label: 'Yangi parol',
                    obscure: _newObscure,
                    onToggle: () =>
                        setState(() => _newObscure = !_newObscure),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Yangi parolni kiriting';
                      if (v.length < 5) {
                        return 'Parol kamida 5 ta belgidan iborat bo\'lsin';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _PasswordField(
                    controller: _confirmPasswordCtrl,
                    label: 'Yangi parolni tasdiqlang',
                    obscure: _confirmObscure,
                    onToggle: () =>
                        setState(() => _confirmObscure = !_confirmObscure),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Parolni tasdiqlang';
                      if (v != _newPasswordCtrl.text) {
                        return 'Parollar mos kelmadi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<SettingsBloc, SettingsState>(
                    builder: (context, state) {
                      final isSubmitting = state is SettingsSubmitting;
                      return FilledButton(
                        onPressed: isSubmitting ? null : _submit,
                        child: isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Saqlash'),
                      );
                    },
                  ),

                  // ── App updates (Android + Windows only) ───────────────
                  if (_updateSupported) ...[
                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 16),
                    _SectionHeader('Ilovani yangilash'),
                    const SizedBox(height: 12),
                    BlocBuilder<AppUpdateBloc, AppUpdateState>(
                      builder: (context, state) {
                        final isChecking = state is AppUpdateChecking;
                        return OutlinedButton.icon(
                          onPressed:
                              isChecking ? null : _checkForUpdates,
                          icon: isChecking
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.system_update_alt),
                          label: Text(
                            isChecking
                                ? 'Tekshirilmoqda…'
                                : 'Yangilanishlarni tekshirish',
                          ),
                        );
                      },
                    ),
                  ],

                  // ── Version info ───────────────────────────────────────
                  const SizedBox(height: 48),
                  if (_version.isNotEmpty)
                    Center(
                      child: Column(
                        children: [
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'TGC Carpets',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Versiya: $_version (Build $_buildNumber)',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color
                                      ?.withOpacity(0.6),
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium!
          .copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }
}


