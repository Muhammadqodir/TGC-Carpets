import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_state.dart';

class AddProductPage extends StatelessWidget {
  const AddProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductFormBloc>(),
      child: const _AddProductView(),
    );
  }
}

class _AddProductView extends StatefulWidget {
  const _AddProductView();

  @override
  State<_AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<_AddProductView> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _lengthCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  final _qualityCtrl = TextEditingController();
  final _densityCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _edgeCtrl = TextEditingController();

  String _unit = 'piece';
  String _status = 'active';
  XFile? _pickedImage;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _qualityCtrl.dispose();
    _densityCtrl.dispose();
    _colorCtrl.dispose();
    _edgeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    context.read<ProductFormBloc>().add(
          ProductFormSubmitted(
            name: _nameCtrl.text.trim(),
            length: _lengthCtrl.text.trim(),
            width: _widthCtrl.text.trim(),
            quality: _qualityCtrl.text.trim(),
            density: _densityCtrl.text.trim(),
            color: _colorCtrl.text.trim(),
            edge: _edgeCtrl.text.trim().isEmpty ? null : _edgeCtrl.text.trim(),
            unit: _unit,
            status: _status,
            imagePath: _pickedImage?.path,
          ),
        );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file != null) {
      setState(() => _pickedImage = file);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedCamera01,
                strokeWidth: 1.5,
              ),
              title: const Text('Rasm olish'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                strokeWidth: 1.5,
              ),
              title: const Text('Galereyadан tanlash'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_pickedImage != null)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text(
                  'Rasmni o\'chirish',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _pickedImage = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductFormBloc, ProductFormState>(
      listener: (context, state) {
        if (state is ProductFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${state.product.name}" mahsuloti yaratildi.'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        } else if (state is ProductFormFailure) {
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
          title: const Text('Mahsulot qo\'shish'),
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
              _ImagePickerWidget(
                pickedImage: _pickedImage,
                onTap: _showImageSourceSheet,
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: 'Asosiy ma\'lumotlar'),
              const SizedBox(height: 12),
              _Field(
                controller: _nameCtrl,
                label: 'Nomi',
                hint: 'masalan: Fors klassik',
                validator: _required,
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: 'O\'lchamlar va xususiyatlar'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _lengthCtrl,
                      label: 'Uzunlik (sm)',
                      hint: '300',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _requiredPositiveInt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _widthCtrl,
                      label: 'Eni (sm)',
                      hint: '200',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: _requiredPositiveInt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _densityCtrl,
                label: 'Zichlik',
                hint: 'masalan: 800',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _requiredPositiveInt,
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: 'Gilam xususiyatlari'),
              const SizedBox(height: 12),
              _Field(
                controller: _qualityCtrl,
                label: 'Sifat',
                hint: 'masalan: premium, standart',
                validator: _required,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _colorCtrl,
                label: 'Rang',
                hint: 'masalan: qizil, ko\'k',
                validator: _required,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: _edgeCtrl,
                label: 'Chegara turi (ixtiyoriy)',
                hint: 'masalan: sacho\', tekis',
              ),
              const SizedBox(height: 20),
              _SectionHeader(title: 'Birlik va holat'),
              const SizedBox(height: 8),
              _SegmentedRow<String>(
                label: 'Birlik',
                options: const {'piece': 'Dona', 'm2': 'm²'},
                selected: _unit,
                onChanged: (v) => setState(() => _unit = v),
              ),
              const SizedBox(height: 12),
              _SegmentedRow<String>(
                label: 'Holat',
                options: const {'active': 'Faol', 'archived': 'Arxivlangan'},
                selected: _status,
                onChanged: (v) => setState(() => _status = v),
              ),
              const SizedBox(height: 28),
              BlocBuilder<ProductFormBloc, ProductFormState>(
                builder: (context, state) {
                  final submitting = state is ProductFormSubmitting;
                  return FilledButton(
                    onPressed: submitting ? null : _submit,
                    child: submitting
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

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Bu maydon to\'ldirilishi shart.' : null;

  String? _requiredPositiveInt(String? v) {
    if (v == null || v.trim().isEmpty) return 'Bu maydon to\'ldirilishi shart.';
    final parsed = int.tryParse(v.trim());
    if (parsed == null || parsed <= 0) return 'Musbat son kiritilishi shart.';
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
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  final String label;
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const _SegmentedRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SegmentedButton<T>(
            style: SegmentedButton.styleFrom(
              backgroundColor: AppColors.background,
              selectedForegroundColor: Colors.white,
              selectedBackgroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            segments: options.entries
                .map((e) => ButtonSegment<T>(
                      value: e.key,
                      label: Text(e.value),
                    ))
                .toList(),
            selected: {selected},
            onSelectionChanged: (s) => onChanged(s.first),
            showSelectedIcon: false,
          ),
        ),
      ],
    );
  }
}

class _ImagePickerWidget extends StatelessWidget {
  final XFile? pickedImage;
  final VoidCallback onTap;

  const _ImagePickerWidget({
    required this.pickedImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(
            color: pickedImage != null
                ? AppColors.primaryLight
                : AppColors.divider,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: pickedImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    File(pickedImage!.path),
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'O\'zgartirish',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedImageUpload,
                    strokeWidth: 1.5,
                    color: AppColors.textSecondary,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Mahsulot rasmini qo\'shish uchun bosing',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'JPG, PNG, WEBP — max 4 MB',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}
