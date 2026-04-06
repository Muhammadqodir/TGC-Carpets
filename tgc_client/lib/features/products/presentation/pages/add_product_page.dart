import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_event.dart';
import 'package:tgc_client/features/products/presentation/bloc/product_form_state.dart';
import 'package:tgc_client/features/products/presentation/widget/product_form_body.dart';

class AddProductPage extends StatelessWidget {
  const AddProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductFormBloc>()..add(const ProductFormStarted()),
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
  final _bodyKey = GlobalKey<ProductFormBodyState>();

  void _submit() => _bodyKey.currentState?.submitToBloc();

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
          titleSpacing: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
        ),
        body: ProductFormBody(
          key: _bodyKey,
          contentPadding: const EdgeInsets.all(16),
          imagePickerHeight: 180,
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
