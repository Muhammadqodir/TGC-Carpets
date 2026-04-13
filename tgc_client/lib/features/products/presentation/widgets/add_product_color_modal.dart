import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/products/domain/entities/color_entity.dart';
import 'package:tgc_client/features/products/domain/entities/product_entity.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_color_form_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_color_form_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_color_form_state.dart';

/// Dialog for adding a new color variant to an existing product.
class AddProductColorModal {
  const AddProductColorModal._();

  static void show(
    BuildContext context, {
    required ProductEntity product,
    required VoidCallback onColorAdded,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => BlocProvider(
        create: (_) =>
            sl<ProductColorFormBloc>()..add(const ProductColorFormStarted()),
        child: _AddColorDialogContent(
          product: product,
          onColorAdded: onColorAdded,
          onClose: () => Navigator.of(dialogCtx).pop(),
        ),
      ),
    );
  }
}

class _AddColorDialogContent extends StatefulWidget {
  const _AddColorDialogContent({
    required this.product,
    required this.onColorAdded,
    required this.onClose,
  });

  final ProductEntity product;
  final VoidCallback onColorAdded;
  final VoidCallback onClose;

  @override
  State<_AddColorDialogContent> createState() => _AddColorDialogContentState();
}

class _AddColorDialogContentState extends State<_AddColorDialogContent> {
  ColorEntity? _selectedColor;
  XFile? _pickedImage;

  Future<void> _pickImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file != null) setState(() => _pickedImage = file);
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => SafeArea(
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
                Navigator.pop(sheetCtx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                strokeWidth: 1.5,
              ),
              title: const Text('Galereyadаn tanlash'),
              onTap: () {
                Navigator.pop(sheetCtx);
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
                  Navigator.pop(sheetCtx);
                  setState(() => _pickedImage = null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final colorId = _selectedColor?.id;
    if (colorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rang tanlang.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rang uchun rasm tanlang.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    context.read<ProductColorFormBloc>().add(
          ProductColorFormSubmitted(
            productId: widget.product.id,
            colorId: colorId,
            imagePath: _pickedImage!.path,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductColorFormBloc, ProductColorFormState>(
      listener: (context, state) {
        if (state is ProductColorFormSuccess) {
          widget.onColorAdded();
          widget.onClose();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '"${widget.product.name}" mahsulotiga rang qo\'shildi.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is ProductColorFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<ProductColorFormBloc, ProductColorFormState>(
        builder: (context, state) {
          final colors = switch (state) {
            ProductColorFormReady s => s.colors,
            ProductColorFormSubmitting s => s.colors,
            ProductColorFormFailure s => s.colors,
            _ => const <ColorEntity>[],
          };
          final isLoading = state is ProductColorFormLoading;
          final isSubmitting = state is ProductColorFormSubmitting;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.product.name} — Rang qo\'shish',
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: widget.onClose,
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<ColorEntity>(
                                decoration: const InputDecoration(
                                  labelText: 'Rang',
                                ),
                                value: _selectedColor,
                                items: colors
                                    .map((c) => DropdownMenuItem<ColorEntity>(
                                          value: c,
                                          child: Text(c.name),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedColor = v),
                                hint: const Text('Rang tanlang'),
                              ),
                              const SizedBox(height: 16),
                              // Image picker
                              SizedBox(
                                width: double.infinity,
                                child: GestureDetector(
                                  onTap: _showImageSourceSheet,
                                  child: Container(
                                    height: 140,
                                    decoration: BoxDecoration(
                                      color: AppColors.background,
                                      border: Border.all(
                                        color: _pickedImage != null
                                            ? AppColors.primaryLight
                                            : AppColors.divider,
                                        width: 1.5,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    clipBehavior: Clip.hardEdge,
                                    child: _pickedImage != null
                                        ? _ImagePreview(
                                            path: _pickedImage!.path)
                                        : _ImagePlaceholder(context),
                                  ),
                                ),
                              )
                            ],
                          ),
                  ),

                  const Divider(height: 1),
                  // Actions
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: isSubmitting ? null : widget.onClose,
                          child: const Text('Bekor qilish'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: isSubmitting ? null : _submit,
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Saqlash'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(File(path), fit: BoxFit.cover),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    );
  }
}

Widget _ImagePlaceholder(BuildContext context) => Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const HugeIcon(
          icon: HugeIcons.strokeRoundedImageUpload,
          strokeWidth: 1.5,
          color: AppColors.textSecondary,
          size: 36,
        ),
        const SizedBox(height: 8),
        Text(
          'Rang rasmi qo\'shish uchun bosing (majburiy)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
