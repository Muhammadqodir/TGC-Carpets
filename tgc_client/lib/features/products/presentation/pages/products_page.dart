import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/features/products/presentation/bloc/products_bloc.dart';
import 'package:tgc_client/features/products/presentation/bloc/products_event.dart';
import 'package:tgc_client/features/products/presentation/pages/products_desktop_page.dart';
import 'package:tgc_client/features/products/presentation/pages/products_mobile_page.dart';

/// Adaptive entry point: dispatches to [ProductsDesktopPage] or
/// [ProductsMobilePage] based on available width.
class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ProductsBloc>()..add(const ProductsLoadRequested()),
      child: const _AdaptiveProductsView(),
    );
  }
}

class _AdaptiveProductsView extends StatelessWidget {
  const _AdaptiveProductsView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
          return const ProductsDesktopPage();
        }
        return const ProductsMobilePage();
      },
    );
  }
}

