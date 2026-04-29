import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';
import 'package:tgc_client/features/clients/presentation/bloc/client_form_bloc.dart';
import 'package:tgc_client/features/clients/presentation/bloc/client_form_event.dart';
import 'package:tgc_client/features/clients/presentation/bloc/client_form_state.dart';

/// Full-screen page for adding or editing a client.
class AddClientPage extends StatelessWidget {
  const AddClientPage({super.key, this.client});

  final ClientEntity? client;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ClientFormBloc>(),
      child: _AddClientView(
        key: client != null ? ValueKey(client!.id) : null,
        client: client,
      ),
    );
  }
}

class _AddClientView extends StatefulWidget {
  const _AddClientView({super.key, this.client});

  final ClientEntity? client;

  @override
  State<_AddClientView> createState() => _AddClientViewState();
}

class _AddClientViewState extends State<_AddClientView> {
  final _formKey = GlobalKey<FormState>();

  final _contactNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    if (c != null) {
      _shopNameCtrl.text = c.shopName;
      _regionCtrl.text = c.region;
      _addressCtrl.text = c.address ?? '';
      _contactNameCtrl.text = c.contactName ?? '';
      _phoneCtrl.text = c.phone ?? '';
      _notesCtrl.text = c.notes ?? '';
    }
  }

  @override
  void dispose() {
    _contactNameCtrl.dispose();
    _phoneCtrl.dispose();
    _shopNameCtrl.dispose();
    _regionCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final clientId = widget.client?.id;

    if (clientId != null) {
      context.read<ClientFormBloc>().add(
            ClientFormUpdateSubmitted(
              clientId: clientId,
              contactName: _contactNameCtrl.text.trim().isEmpty
                  ? null
                  : _contactNameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim().isEmpty
                  ? null
                  : _phoneCtrl.text.trim(),
              shopName: _shopNameCtrl.text.trim(),
              region: _regionCtrl.text.trim(),
              address: _addressCtrl.text.trim().isEmpty
                  ? null
                  : _addressCtrl.text.trim(),
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            ),
          );
    } else {
      context.read<ClientFormBloc>().add(
            ClientFormSubmitted(
              contactName: _contactNameCtrl.text.trim().isEmpty
                  ? null
                  : _contactNameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim().isEmpty
                  ? null
                  : _phoneCtrl.text.trim(),
              shopName: _shopNameCtrl.text.trim(),
              region: _regionCtrl.text.trim(),
              address: _addressCtrl.text.trim().isEmpty
                  ? null
                  : _addressCtrl.text.trim(),
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.client != null;

    return BlocListener<ClientFormBloc, ClientFormState>(
      listener: (context, state) {
        if (state is ClientFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing
                    ? '"${state.client.shopName}" yangilandi.'
                    : '"${state.client.shopName}" mijozi yaratildi.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        } else if (state is ClientFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Mijozni tahrirlash' : 'Mijoz qo\'shish'),
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
              _SectionHeader(title: 'Do\'kon ma\'lumotlari'),
              const SizedBox(height: 12),
              _Field(
                controller: _shopNameCtrl,
                label: 'Do\'kon nomi',
                hint: 'masalan: Firdavs Gilam',
                validator: _required,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _regionCtrl,
                label: 'Viloyat / Shahar',
                hint: 'masalan: Toshkent',
                validator: _required,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _addressCtrl,
                label: 'Manzil (ixtiyoriy)',
                hint: 'masalan: Chilonzor, 12-uy',
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Kontakt ma\'lumotlari'),
              const SizedBox(height: 12),
              _Field(
                controller: _contactNameCtrl,
                label: 'Ism-familiya (ixtiyoriy)',
                hint: 'masalan: Firdavs Toshmatov',
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _phoneCtrl,
                label: 'Telefon raqam (ixtiyoriy)',
                hint: '+998901234567',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: 'Qo\'shimcha'),
              const SizedBox(height: 12),
              _Field(
                controller: _notesCtrl,
                label: 'Izohlar (ixtiyoriy)',
                hint: 'Qo\'shimcha ma\'lumotlar...',
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              BlocBuilder<ClientFormBloc, ClientFormState>(
                builder: (context, state) {
                  final isLoading = state is ClientFormSubmitting;
                  return FilledButton(
                    onPressed: isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: isLoading
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bu maydon majburiy.';
    }
    return null;
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}
