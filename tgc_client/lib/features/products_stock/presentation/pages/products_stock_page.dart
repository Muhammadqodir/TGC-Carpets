import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_bloc.dart';
import 'package:tgc_client/features/products_stock/presentation/bloc/products_stock_event.dart';
import 'package:tgc_client/features/products_stock/presentation/pages/products_stock_desktop_page.dart';

/// Entry point for Products Stock screen - uses adaptive desktop view.
class ProductsStockPage extends StatelessWidget {
  const ProductsStockPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<ProductsStockBloc>()..add(const ProductsStockLoadRequested()),
      child: const ProductsStockDesktopPage(),
    );
  }
}
