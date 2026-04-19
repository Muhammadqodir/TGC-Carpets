import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';
import 'package:tgc_client/features/clients/presentation/bloc/client_form_bloc.dart';
import 'package:tgc_client/features/clients/presentation/bloc/client_form_event.dart';

/// Shared client form fields widget.
///
/// Used by both [AddClientPage] (mobile/full-screen) and
/// [AddClientModal] (desktop dialog). All form state lives here.
///
/// Access [ClientFormBodyState] via a [GlobalKey] to call [submitToBloc].
///
/// ```dart
/// final _key = GlobalKey<ClientFormBodyState>();
/// ClientFormBody(key: _key, contentPadding: EdgeInsets.all(16))
/// _key.currentState!.submitToBloc();
/// ```
class ClientFormBody extends StatefulWidget {
  const ClientFormBody({
    super.key,
    this.contentPadding = const EdgeInsets.all(16),
    this.initialClient,
  });

  final EdgeInsetsGeometry contentPadding;

  /// When provided the form pre-fills its fields for editing.
  final ClientEntity? initialClient;

  @override
  State<ClientFormBody> createState() => ClientFormBodyState();
}

class ClientFormBodyState extends State<ClientFormBody> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final c = widget.initialClient;
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
    _shopNameCtrl.dispose();
    _regionCtrl.dispose();
    _addressCtrl.dispose();
    _contactNameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Validates and dispatches [ClientFormSubmitted] or [ClientFormUpdateSubmitted].
  bool submitToBloc() {
    if (!_formKey.currentState!.validate()) return false;

    final clientId = widget.initialClient?.id;
    final contactName =
        _contactNameCtrl.text.trim().isEmpty ? null : _contactNameCtrl.text.trim();
    final phone =
        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();
    final shopName = _shopNameCtrl.text.trim();
    final region = _regionCtrl.text.trim();
    final address =
        _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    if (clientId != null) {
      context.read<ClientFormBloc>().add(ClientFormUpdateSubmitted(
            clientId: clientId,
            contactName: contactName,
            phone: phone,
            shopName: shopName,
            region: region,
            address: address,
            notes: notes,
          ));
    } else {
      context.read<ClientFormBloc>().add(ClientFormSubmitted(
            contactName: contactName,
            phone: phone,
            shopName: shopName,
            region: region,
            address: address,
            notes: notes,
          ));
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: widget.contentPadding,
        children: [
          _FormSectionHeader(title: 'Do\'kon ma\'lumotlari'),
          const SizedBox(height: 12),
          _FormField(
            controller: _shopNameCtrl,
            label: 'Do\'kon nomi',
            hint: 'masalan: Firdavs Gilam',
            validator: _required,
          ),
          const SizedBox(height: 12),
          _FormField(
            controller: _regionCtrl,
            label: 'Viloyat / Shahar',
            hint: 'masalan: Toshkent',
            validator: _required,
          ),
          const SizedBox(height: 12),
          _FormField(
            controller: _addressCtrl,
            label: 'Manzil (ixtiyoriy)',
            hint: 'masalan: Chilonzor, 12-uy',
          ),
          const SizedBox(height: 24),
          _FormSectionHeader(title: 'Kontakt ma\'lumotlari'),
          const SizedBox(height: 12),
          _FormField(
            controller: _contactNameCtrl,
            label: 'Ism-familiya (ixtiyoriy)',
            hint: 'masalan: Firdavs Toshmatov',
          ),
          const SizedBox(height: 12),
          _FormField(
            controller: _phoneCtrl,
            label: 'Telefon raqam (ixtiyoriy)',
            hint: '+998901234567',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),
          _FormSectionHeader(title: 'Qo\'shimcha'),
          const SizedBox(height: 12),
          _FormField(
            controller: _notesCtrl,
            label: 'Izohlar (ixtiyoriy)',
            hint: 'Qo\'shimcha ma\'lumotlar...',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Bu maydon to\'ldirilishi shart.' : null;
}

// ---------------------------------------------------------------------------

class _FormSectionHeader extends StatelessWidget {
  const _FormSectionHeader({required this.title});

  final String title;

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

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
