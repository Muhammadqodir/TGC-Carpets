import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/core/ui/widgets/app_option_selector.dart';
import 'package:tgc_client/features/products/domain/entities/product_entity.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_state.dart';

/// The shared product form fields widget.
///
/// Used by both [AddProductPage] (mobile/full-screen scaffold) and
/// [AddProductModal] (desktop dialog). All form state lives here.
///
/// Access [ProductFormBodyState] via a [GlobalKey] to call [submitToBloc].
///
/// ```dart
/// final _formKey = GlobalKey<ProductFormBodyState>();
/// // ...
/// ProductFormBody(key: _formKey, contentPadding: EdgeInsets.all(16))
/// // ...
/// _formKey.currentState!.submitToBloc();
/// ```
class ProductFormBody extends StatefulWidget {
  const ProductFormBody({
    super.key,
    this.contentPadding = const EdgeInsets.all(16),
    this.initialProduct,
  });

  final EdgeInsetsGeometry contentPadding;

  /// When provided the form pre-fills its fields for editing.
  final ProductEntity? initialProduct;

  @override
  State<ProductFormBody> createState() => ProductFormBodyState();
}

class ProductFormBodyState extends State<ProductFormBody> {
  final _formKey = GlobalKey<FormState>();

  final nameCtrl = TextEditingController();

  int? selectedTypeId;
  int? selectedQualityId;
  String unit = 'piece';
  String status = 'active';

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    if (p != null) {
      nameCtrl.text = p.name;
      selectedTypeId = p.productTypeId;
      selectedQualityId = p.productQualityId;
      unit = p.unit;
      status = p.status;
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  /// Validates all fields and dispatches [ProductFormSubmitted] to the nearest
  /// [ProductFormBloc]. Returns `false` if validation fails.
  bool submitToBloc() {
    if (!_formKey.currentState!.validate()) return false;
    final productId = widget.initialProduct?.id;
    if (productId != null) {
      context.read<ProductFormBloc>().add(
            ProductFormUpdateSubmitted(
              productId: productId,
              name: nameCtrl.text.trim(),
              productTypeId: selectedTypeId,
              productQualityId: selectedQualityId,
              unit: unit,
              status: status,
            ),
          );
    } else {
      context.read<ProductFormBloc>().add(
            ProductFormSubmitted(
              name: nameCtrl.text.trim(),
              productTypeId: selectedTypeId,
              productQualityId: selectedQualityId,
              unit: unit,
              status: status,
            ),
          );
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
          // Section: basic info
          _FormSectionHeader(title: 'Asosiy ma\'lumotlar'),
          const SizedBox(height: 12),
          _FormField(
            controller: nameCtrl,
            label: 'Nomi',
            hint: 'masalan: Fors klassik',
            validator: _required,
          ),
          const SizedBox(height: 20),

          // Section: attributes
          _FormSectionHeader(title: 'Xususiyatlar'),
          const SizedBox(height: 12),
          BlocBuilder<ProductFormBloc, ProductFormState>(
            builder: (context, state) {
              if (state is ProductFormTypesLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              final types = switch (state) {
                ProductFormReady s => s.productTypes,
                ProductFormSubmitting s => s.productTypes,
                ProductFormFailure s => s.productTypes,
                _ => const [],
              };
              final qualities = switch (state) {
                ProductFormReady s => s.productQualities,
                ProductFormSubmitting s => s.productQualities,
                ProductFormFailure s => s.productQualities,
                _ => const [],
              };
              return Column(
                children: [
                  DropdownButtonFormField<int>(
                    decoration:
                        const InputDecoration(labelText: 'Mahsulot turi'),
                    value: selectedTypeId,
                    items: types
                        .map((t) => DropdownMenuItem<int>(
                              value: t.id,
                              child: Text(t.type),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => selectedTypeId = v),
                    hint: const Text('Tur tanlang (ixtiyoriy)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    decoration:
                        const InputDecoration(labelText: 'Sifat'),
                    value: selectedQualityId,
                    items: qualities
                        .map((q) => DropdownMenuItem<int>(
                              value: q.id,
                              child: Text(q.density != null
                                  ? '${q.qualityName} (${q.density})'
                                  : q.qualityName),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => selectedQualityId = v),
                    hint: const Text('Sifat tanlang (ixtiyoriy)'),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Section: unit & status
          _FormSectionHeader(title: 'Birlik va holat'),
          const SizedBox(height: 8),
          AppOptionSelector<String>(
            label: 'Birlik',
            options: const [
              (label: 'Dona', value: 'piece'),
              (label: 'm²', value: 'm2'),
            ],
            selected: unit,
            onChanged: (v) => setState(() => unit = v),
          ),
          const SizedBox(height: 12),
          AppOptionSelector<String>(
            label: 'Holat',
            options: const [
              (label: 'Faol', value: 'active'),
              (label: 'Arxivlangan', value: 'archived'),
            ],
            selected: status,
            onChanged: (v) => setState(() => status = v),
          ),
        ],
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty)
          ? 'Bu maydon to\'ldirilishi shart.'
          : null;
}

// ---------------------------------------------------------------------------
// Private helpers (scoped to this file)
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
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}
