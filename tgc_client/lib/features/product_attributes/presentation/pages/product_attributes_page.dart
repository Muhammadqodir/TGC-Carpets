import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../bloc/product_attributes_bloc.dart';
import '../bloc/product_attributes_event.dart';
import 'product_attributes_desktop_page.dart';
import 'product_attributes_mobile_page.dart';

class ProductAttributesPage extends StatelessWidget {
  const ProductAttributesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductAttributesBloc>()
        ..add(const ProductAttributesLoadRequested()),
      child: const _AdaptiveView(),
    );
  }
}

class _AdaptiveView extends StatelessWidget {
  const _AdaptiveView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return const ProductAttributesDesktopPage();
        }
        return const ProductAttributesMobilePage();
      },
    );
  }
}
