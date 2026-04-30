import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../di/injection.dart';
import '../../features/products/domain/entities/product_entity.dart';
import '../../features/products/presentation/pages/products_page.dart';
import '../../features/products/presentation/pages/add_product_page.dart';
import '../../features/clients/domain/entities/client_entity.dart';
import '../../features/clients/presentation/pages/clients_page.dart';
import '../../features/clients/presentation/pages/add_client_page.dart';
import '../../features/warehouse_documents/presentation/pages/warehouse_documents_page.dart';
import '../../features/warehouse_documents/presentation/pages/add_warehouse_document_page.dart';
import '../../features/warehouse_documents/presentation/pages/warehouse_document_preview_page.dart';
import '../../features/warehouse_documents/presentation/pages/args/warehouse_document_preview_args.dart';
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
import '../../features/production/presentation/pages/defect_document_form_page.dart';
import '../../features/production/domain/entities/production_batch_entity.dart';
import '../../features/labeling/presentation/pages/labeling_page.dart';
import '../../features/products_stock/presentation/pages/products_stock_page.dart';
import '../../features/shipments/presentation/pages/shipments_page.dart';
import '../../features/shipments/presentation/pages/add_shipment_page.dart';
import '../../features/payments/presentation/pages/payments_page.dart';
import '../../features/payments/presentation/pages/add_payment_page.dart';
import '../../features/debits/domain/entities/client_debit_entity.dart';
import '../../features/debits/presentation/pages/debits_page.dart';
import '../../features/product_attributes/presentation/pages/product_attributes_page.dart';
import '../../features/debits/presentation/pages/client_debit_detail_page.dart';
import '../../features/raw_materials/presentation/pages/raw_materials_page.dart';
import '../../features/raw_materials/presentation/pages/add_raw_material_page.dart';
import '../../features/raw_materials/presentation/pages/raw_material_batch_movement_page.dart';
import '../storage/token_storage.dart';
import 'app_routes.dart';

class AppRouter {
  final TokenStorage _tokenStorage;

  AppRouter(this._tokenStorage);

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: _handleRedirect,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (context, state) => BlocProvider.value(
          value: sl<AuthBloc>(),
          child: const SplashPage(),
        ),
      ),
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
            builder: (context, state) => AddProductPage(
              product: state.extra as ProductEntity?,
            ),
          ),
          GoRoute(
            path: AppRoutes.clients,
            name: AppRoutes.clientsName,
            builder: (context, state) => const ClientsPage(),
          ),
          GoRoute(
            path: AppRoutes.addClient,
            name: AppRoutes.addClientName,
            builder: (context, state) => AddClientPage(
              client: state.extra as ClientEntity?,
            ),
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
          GoRoute(
            path: AppRoutes.defectDocumentForm,
            name: AppRoutes.defectDocumentFormName,
            builder: (context, state) {
              final batch = state.extra as ProductionBatchEntity;
              return DefectDocumentFormPage(batch: batch);
            },
          ),
          GoRoute(
            path: AppRoutes.labeling,
            name: AppRoutes.labelingName,
            builder: (context, state) => const LabelingPage(),
          ),
          GoRoute(
            path: AppRoutes.productsStock,
            name: AppRoutes.productsStockName,
            builder: (context, state) => const ProductsStockPage(),
          ),
          GoRoute(
            path: AppRoutes.shipping,
            name: AppRoutes.shippingName,
            builder: (context, state) => const ShipmentsPage(),
          ),
          GoRoute(
            path: AppRoutes.addShipping,
            name: AppRoutes.addShippingName,
            builder: (context, state) => const AddShipmentPage(),
          ),
          GoRoute(
            path: AppRoutes.payments,
            name: AppRoutes.paymentsName,
            builder: (context, state) => const PaymentsPage(),
          ),
          GoRoute(
            path: AppRoutes.addPayment,
            name: AppRoutes.addPaymentName,
            builder: (context, state) {
              final client = state.extra as ClientEntity?;
              return AddPaymentPage(initialClient: client);
            },
          ),
          GoRoute(
            path: AppRoutes.debits,
            name: AppRoutes.debitsName,
            builder: (context, state) => const DebitsPage(),
          ),
          GoRoute(
            path: AppRoutes.productAttributes,
            name: AppRoutes.productAttributesName,
            builder: (context, state) => const ProductAttributesPage(),
          ),
          GoRoute(
            path: AppRoutes.clientDebitDetail,
            name: AppRoutes.clientDebitDetailName,
            builder: (context, state) {
              final client = state.extra as ClientDebitEntity;
              return ClientDebitDetailPage(client: client);
            },
          ),
          GoRoute(
            path: AppRoutes.rawMaterials,
            name: AppRoutes.rawMaterialsName,
            builder: (context, state) => const RawMaterialsPage(),
          ),
          GoRoute(
            path: AppRoutes.addRawMaterial,
            name: AppRoutes.addRawMaterialName,
            builder: (context, state) => const AddRawMaterialPage(),
          ),
          GoRoute(
            path: AppRoutes.rawMaterialBatchMovement,
            name: AppRoutes.rawMaterialBatchMovementName,
            builder: (context, state) => const RawMaterialBatchMovementPage(),
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
    final isOnSplash = state.matchedLocation == AppRoutes.splash;
    final isOnLogin = state.matchedLocation == AppRoutes.login;

    // Allow splash and login pages without redirect
    if (isOnSplash || isOnLogin) return null;

    // For all other routes, check authentication
    final token = await _tokenStorage.getToken();
    final isLoggedIn = token != null && token.isNotEmpty;

    // If not logged in and trying to access protected route, redirect to login
    if (!isLoggedIn) return AppRoutes.login;
    
    return null;
  }
}

class _MainShell extends StatelessWidget {
  final Widget child;

  const _MainShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<AuthBloc>(),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          // When user logs out, navigate to login page
          if (state is AuthUnauthenticated) {
            context.goNamed(AppRoutes.loginName);
          }
        },
        child: child,
      ),
    );
  }
}
