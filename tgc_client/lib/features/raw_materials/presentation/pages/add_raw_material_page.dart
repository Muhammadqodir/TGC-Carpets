import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_option_selector.dart';
import '../bloc/raw_material_form_bloc.dart';
import '../bloc/raw_material_form_event.dart';
import '../bloc/raw_material_form_state.dart';

/// Page for adding a new raw material.
class AddRawMaterialPage extends StatelessWidget {
  const AddRawMaterialPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<RawMaterialFormBloc>(),
      child: const _AddRawMaterialView(),
    );
  }
}

class _AddRawMaterialView extends StatefulWidget {
  const _AddRawMaterialView();

  @override
  State<_AddRawMaterialView> createState() => _AddRawMaterialViewState();
}

class _AddRawMaterialViewState extends State<_AddRawMaterialView> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  String _unit    = 'piece';

  static const _units = [
    (label: 'Dona', value: 'piece'),
    (label: 'm²',   value: 'sqm'),
    (label: 'kg',   value: 'kg'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<RawMaterialFormBloc>().add(RawMaterialFormSubmitted(
          name: _nameCtrl.text.trim(),
          type: _typeCtrl.text.trim(),
          unit: _unit,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RawMaterialFormBloc, RawMaterialFormState>(
      listener: (context, state) {
        if (state is RawMaterialFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('"${state.material.name}" xom ashyo qo\'shildi.'),
            backgroundColor: AppColors.success,
          ));
          context.pop(true);
        } else if (state is RawMaterialFormError) {
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
          title: const Text('Xom ashyo qo\'shish'),
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
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nomi *',
                  hintText: 'Masalan: PP Ip',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom kiritish shart' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _typeCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Turi *',
                  hintText: 'Masalan: Ip, Kimyo, Material',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Tur kiritish shart' : null,
              ),
              const SizedBox(height: 18),
              AppOptionSelector<String>(
                label: 'O\'lchov birligi',
                options: _units,
                selected: _unit,
                onChanged: (v) => setState(() => _unit = v),
              ),
              const SizedBox(height: 28),
              BlocBuilder<RawMaterialFormBloc, RawMaterialFormState>(
                builder: (context, state) {
                  return FilledButton(
                    onPressed:
                        state is RawMaterialFormLoading ? null : _submit,
                    child: state is RawMaterialFormLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Saqlash'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
