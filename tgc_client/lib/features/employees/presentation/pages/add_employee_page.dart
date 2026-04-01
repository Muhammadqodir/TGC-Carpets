import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/widgets/app_option_selector.dart';
import '../bloc/employee_form_bloc.dart';
import '../bloc/employee_form_event.dart';
import '../bloc/employee_form_state.dart';

class AddEmployeePage extends StatelessWidget {
  const AddEmployeePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<EmployeeFormBloc>(),
      child: const _AddEmployeeView(),
    );
  }
}

class _AddEmployeeView extends StatefulWidget {
  const _AddEmployeeView();

  @override
  State<_AddEmployeeView> createState() => _AddEmployeeViewState();
}

class _AddEmployeeViewState extends State<_AddEmployeeView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _passwordVisible = false;
  String _selectedRole = 'seller';

  static const _roles = [
    (label: 'Sotuvchi', value: 'seller'),
    (label: 'Ombor', value: 'warehouse'),
    (label: 'Admin', value: 'admin'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<EmployeeFormBloc>().add(EmployeeFormSubmitted(
          name: _nameCtrl.text.trim(),
          email: '${_emailCtrl.text.trim()}@tgc-carpets.uz',
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: _selectedRole,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<EmployeeFormBloc, EmployeeFormState>(
      listener: (context, state) {
        if (state is EmployeeFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '"${state.employee.name}" hodimi muvaffaqiyatli qo\'shildi.'),
            backgroundColor: AppColors.success,
          ));
          context.pop(true);
        } else if (state is EmployeeFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(state.message), backgroundColor: AppColors.error),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hodim qo\'shish'),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionHeader(title: 'Shaxsiy ma\'lumotlar'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ism-familiya',
                  hintText: 'masalan: Jasur Xolmatov',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Bu maydon majburiy.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'jasur',
                  suffixText: '@tgc-carpets.uz',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email majburiy.';
                  final username = v.trim();
                  if (username.contains('@') || username.contains(' '))
                    return 'Faqat foydalanuvchi nomini kiriting.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefon (ixtiyoriy)',
                  hintText: '+998901234567',
                ),
              ),
              const SizedBox(height: 24),
              const _SectionHeader(title: 'Kirish ma\'lumotlari'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Parol',
                  hintText: 'Kamida 8 ta belgi',
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Parol majburiy.';
                  if (v.length < 8)
                    return 'Parol kamida 8 ta belgidan iborat bo\'lishi kerak.';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const _SectionHeader(title: 'Lavozim'),
              const SizedBox(height: 12),
              AppOptionSelector<String>(
                options: _roles,
                selected: _selectedRole,
                onChanged: (role) => setState(() => _selectedRole = role),
              ),
              const SizedBox(height: 32),
              BlocBuilder<EmployeeFormBloc, EmployeeFormState>(
                builder: (context, state) {
                  final isLoading = state is EmployeeFormSubmitting;
                  return FilledButton(
                    onPressed: isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Saqlash'),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}



class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
      );
}
