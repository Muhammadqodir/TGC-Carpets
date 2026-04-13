import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_bloc.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_event.dart';
import 'package:tgc_client/features/products_stock/presentation/pages/products_stock_desktop_page.dart';
import 'package:tgc_client/features/products_stock/presentation/pages/products_stock_mobile_page.dart';

/// Adaptive entry point: dispatches to desktop or mobile view based on width.
class ProductsStockPage extends StatelessWidget {
  const ProductsStockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ProductsStockBloc>()..add(const ProductsStockLoadRequested()),
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
          return const ProductsStockDesktopPage();
        }
        return const ProductsStockMobilePage();
      },
    );
  }
}
