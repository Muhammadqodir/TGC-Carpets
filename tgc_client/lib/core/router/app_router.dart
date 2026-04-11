import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/products/presentation/pages/add_product_page.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/clients/presentation/pages/add_client_page.dart';
import '../../features/warehouse/presentation/pages/warehouse_documents_page.dart';
import '../../features/warehouse/presentation/pages/add_warehouse_document_page.dart';
import '../../features/warehouse/presentation/pages/warehouse_document_preview_page.dart';
import '../../features/warehouse/presentation/pages/args/warehouse_document_preview_args.dart';
import '../../features/warehouse/presentation/pages/print_labels_page.dart';
import '../../features/warehouse/presentation/pages/args/print_labels_args.dart';
import '../../features/sales/presentation/pages/sales_page.dart';
import '../../features/sales/presentation/pages/add_sale_page.dart';
import '../../features/employees/presentation/pages/employees_page.dart';
import '../../features/employees/presentation/pages/add_employee_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/orders/presentation/pages/orders_page.dart';
import '../../features/orders/presentation/pages/order_form_page.dart';
import '../../features/orders/presentation/pages/order_detail_page.dart';
import '../../features/orders/presentation/pages/args/order_detail_args.dart';
import '../../features/orders/domain/entities/order_entity.dart';
import '../../features/production/presentation/pages/production_batches_page.dart';
import '../../features/production/presentation/pages/production_batch_form_page.dart';
import '../../features/production/presentation/pages/production_batch_detail_page.dart';
import '../../features/production/domain/entities/production_batch_entity.dart';
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
            builder: (context, state) => const WarehouseDocumentsPage(),
          ),
          GoRoute(
            path: AppRoutes.addWarehouseDocument,
            name: AppRoutes.addWarehouseDocumentName,
            builder: (context, state) => const AddWarehouseDocumentPage(),
          ),
          GoRoute(
            path: AppRoutes.warehouseDocumentPreview,
            name: AppRoutes.warehouseDocumentPreviewName,
            builder: (context, state) {
              final args = state.extra as WarehouseDocumentPreviewArgs;
              return WarehouseDocumentPreviewPage(args: args);
            },
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
          GoRoute(
            path: AppRoutes.employees,
            name: AppRoutes.employeesName,
            builder: (context, state) => const EmployeesPage(),
          ),
          GoRoute(
            path: AppRoutes.addEmployee,
            name: AppRoutes.addEmployeeName,
            builder: (context, state) => const AddEmployeePage(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: AppRoutes.settingsName,
            builder: (context, state) => const SettingsPage(),
          ),
          GoRoute(
            path: AppRoutes.orders,
            name: AppRoutes.ordersName,
            builder: (context, state) => const OrdersPage(),
          ),
          GoRoute(
            path: AppRoutes.addOrder,
            name: AppRoutes.addOrderName,
            builder: (context, state) => const OrderFormPage(),
          ),
          GoRoute(
            path: AppRoutes.orderDetail,
            name: AppRoutes.orderDetailName,
            builder: (context, state) {
              final args = state.extra as OrderDetailArgs;
              return OrderDetailPage(args: args);
            },
          ),
          GoRoute(
            path: AppRoutes.editOrder,
            name: AppRoutes.editOrderName,
            builder: (context, state) {
              final order = state.extra as OrderEntity;
              return OrderFormPage(order: order);
            },
          ),
          GoRoute(
            path: AppRoutes.production,
            name: AppRoutes.productionName,
            builder: (context, state) => const ProductionBatchesPage(),
          ),
          GoRoute(
            path: AppRoutes.addProductionBatch,
            name: AppRoutes.addProductionBatchName,
            builder: (context, state) => const ProductionBatchFormPage(),
          ),
          GoRoute(
            path: AppRoutes.editProductionBatch,
            name: AppRoutes.editProductionBatchName,
            builder: (context, state) {
              final batch = state.extra as ProductionBatchEntity;
              return ProductionBatchFormPage(batch: batch);
            },
          ),
          GoRoute(
            path: AppRoutes.productionBatchDetail,
            name: AppRoutes.productionBatchDetailName,
            builder: (context, state) {
              final batch = state.extra as ProductionBatchEntity;
              return ProductionBatchDetailPage(batch: batch);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.printLabels,
        name: AppRoutes.printLabelsName,
        builder: (context, state) {
          final args = state.extra as PrintLabelsArgs;
          return PrintLabelsPage(args: args);
        },
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
