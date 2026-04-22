import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/products/domain/entities/product_entity.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_state.dart';
import 'package:tgc_client/features/products/presentation/widgets/product_form_body.dart';

class AddProductPage extends StatelessWidget {
  const AddProductPage({super.key, this.product});

  final ProductEntity? product;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductFormBloc>()..add(const ProductFormStarted()),
      child: _AddProductView(product: product),
    );
  }
}

class _AddProductView extends StatefulWidget {
  const _AddProductView({this.product});

  final ProductEntity? product;

  @override
  State<_AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<_AddProductView> {
  final _bodyKey = GlobalKey<ProductFormBodyState>();

  void _submit() => _bodyKey.currentState?.submitToBloc();

  bool get _isEditing => widget.product != null;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProductFormBloc, ProductFormState>(
      listener: (context, state) {
        if (state is ProductFormSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? '"${state.product.name}" yangilandi.'
                    : '"${state.product.name}" mahsuloti yaratildi.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(true);
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
          title: Text(_isEditing ? 'Mahsulotni tahrirlash' : 'Mahsulot qo\'shish'),
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
        ),
        body: ProductFormBody(
          key: _bodyKey,
          contentPadding: const EdgeInsets.all(16),
          initialProduct: widget.product,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: BlocBuilder<ProductFormBloc, ProductFormState>(
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
          ),
        ),
      ),
    );
  }
}
