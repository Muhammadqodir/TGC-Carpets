import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/products/presentation/pages/add_product_page.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/clients/presentation/pages/add_client_page.dart';
import '../../features/warehouse/presentation/pages/warehouse_page.dart';
import '../../features/warehouse/presentation/pages/add_warehouse_document_page.dart';
import '../../features/sales/presentation/pages/sales_page.dart';
import '../../features/sales/presentation/pages/add_sale_page.dart';
import '../storage/token_storage.dart';
import 'app_routes.dart';

class AppRouter {
  final TokenStorage _tokenStorage;

  AppRouter(this._tokenStorage);

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    redirect: _handleRedirect,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => _MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: AppRoutes.dashboardName,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.products,
            name: AppRoutes.productsName,
            builder: (context, state) => const ProductsPage(),
          ),
          GoRoute(
            path: AppRoutes.addProduct,
            name: AppRoutes.addProductName,
            builder: (context, state) => const AddProductPage(),
          ),
          GoRoute(
            path: AppRoutes.clients,
            name: AppRoutes.clientsName,
            builder: (context, state) => const ClientsPage(),
          ),
          GoRoute(
            path: AppRoutes.addClient,
            name: AppRoutes.addClientName,
            builder: (context, state) => const AddClientPage(),
          ),
          GoRoute(
            path: AppRoutes.warehouse,
            name: AppRoutes.warehouseName,
            builder: (context, state) => const WarehousePage(),
          ),
          GoRoute(
            path: AppRoutes.addWarehouseDocument,
            name: AppRoutes.addWarehouseDocumentName,
            builder: (context, state) => const AddWarehouseDocumentPage(),
          ),
          GoRoute(
            path: AppRoutes.sales,
            name: AppRoutes.salesName,
            builder: (context, state) => const SalesPage(),
          ),
          GoRoute(
            path: AppRoutes.addSale,
            name: AppRoutes.addSaleName,
            builder: (context, state) => const AddSalePage(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );

  Future<String?> _handleRedirect(
    BuildContext context,
    GoRouterState state,
  ) async {
    final token = await _tokenStorage.getToken();
    final isLoggedIn = token != null && token.isNotEmpty;
    final isOnLogin = state.matchedLocation == AppRoutes.login;

    if (!isLoggedIn && !isOnLogin) return AppRoutes.login;
    if (isLoggedIn && isOnLogin) return AppRoutes.dashboard;
    return null;
  }
}

class _MainShell extends StatelessWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context) => child;
}
