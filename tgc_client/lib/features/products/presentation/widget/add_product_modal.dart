import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/products/domain/entities/product_entity.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_state.dart';
import 'package:tgc_client/features/products/presentation/widget/product_form_body.dart';

/// Shows the add-product form inside a desktop dialog.
/// On success calls [onProductAdded] then closes.
class AddProductModal {
  const AddProductModal._();

  static void show(
    BuildContext context, {
    required VoidCallback onProductAdded,
    ProductEntity? product,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => BlocProvider(
        create: (_) => sl<ProductFormBloc>()..add(const ProductFormStarted()),
        child: _AddProductDialogContent(
          onProductAdded: onProductAdded,
          onClose: () => Navigator.of(dialogCtx).pop(),
          product: product,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AddProductDialogContent extends StatefulWidget {
  const _AddProductDialogContent({
    required this.onProductAdded,
    required this.onClose,
    this.product,
  });

  final VoidCallback onProductAdded;
  final VoidCallback onClose;
  final ProductEntity? product;

  @override
  State<_AddProductDialogContent> createState() =>
      _AddProductDialogContentState();
}

class _AddProductDialogContentState
    extends State<_AddProductDialogContent> {
  final _bodyKey = GlobalKey<ProductFormBodyState>();

  void _submit() => _bodyKey.currentState?.submitToBloc();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductFormBloc, ProductFormState>(
      listener: (context, state) {
        if (state is ProductFormSuccess) {
          widget.onProductAdded();
          widget.onClose();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.product != null
                    ? '"${state.product.name}" yangilandi.'
                    : '"${state.product.name}" mahsuloti yaratildi.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is ProductFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 560,
          height: 680,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title bar
              _DialogTitleBar(
                title: widget.product != null
                    ? 'Mahsulotni tahrirlash'
                    : 'Mahsulot qo\'shish',
                onClose: widget.onClose,
              ),
              const Divider(height: 1, color: AppColors.divider),

              // Shared form body
              Expanded(
                child: ProductFormBody(
                  key: _bodyKey,
                  contentPadding: const EdgeInsets.all(20),
                  imagePickerHeight: 150,
                  initialProduct: widget.product,
                ),
              ),

              // Action buttons
              const Divider(height: 1, color: AppColors.divider),
              _DialogActions(
                onCancel: widget.onClose,
                onSave: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DialogTitleBar extends StatelessWidget {
  const _DialogTitleBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Yopish',
          ),
        ],
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({required this.onCancel, required this.onSave});

  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: onCancel,
            child: const Text('Bekor qilish'),
          ),
          const SizedBox(width: 12),
          BlocBuilder<ProductFormBloc, ProductFormState>(
            builder: (context, state) {
              final submitting = state is ProductFormSubmitting;
              return FilledButton(
                onPressed: submitting ? null : onSave,
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Saqlash'),
              );
            },
          ),
        ],
      ),
    );
  }
}
