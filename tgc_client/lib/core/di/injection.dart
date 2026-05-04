import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../network/interceptors/auth_interceptor.dart';
import '../network/network_info.dart';
import '../router/app_router.dart';
import '../storage/token_storage.dart';

// Auth feature
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';

// Products feature
import '../../features/products/data/datasources/product_remote_datasource.dart';
import '../../features/products/data/repositories/product_repository_impl.dart';
import '../../features/products/domain/repositories/product_repository.dart';
import '../../features/products/domain/usecases/get_products_usecase.dart';
import '../../features/products/domain/usecases/get_product_types_usecase.dart';
import '../../features/products/domain/usecases/get_product_qualities_usecase.dart';
import '../../features/products/domain/usecases/get_product_sizes_usecase.dart';
import '../../features/products/domain/usecases/create_product_usecase.dart';
import '../../features/products/domain/usecases/update_product_usecase.dart';
import '../../features/products/domain/usecases/delete_product_usecase.dart';
import '../../features/products/domain/usecases/create_product_color_usecase.dart';
import '../../features/products/domain/usecases/delete_product_color_usecase.dart';
import '../../features/products/domain/usecases/get_colors_usecase.dart';
import '../../features/products/presentation/bloc/products_bloc.dart';
import '../../features/products/presentation/bloc/product_form_bloc.dart';
import '../../features/products/presentation/bloc/product_color_form_bloc.dart';

// Clients feature
import '../../features/clients/data/datasources/client_remote_datasource.dart';
import '../../features/clients/data/repositories/client_repository_impl.dart';
import '../../features/clients/domain/repositories/client_repository.dart';
import '../../features/clients/domain/usecases/get_clients_usecase.dart';
import '../../features/clients/domain/usecases/create_client_usecase.dart';
import '../../features/clients/domain/usecases/update_client_usecase.dart';
import '../../features/clients/domain/usecases/delete_client_usecase.dart';
import '../../features/clients/presentation/bloc/clients_bloc.dart';
import '../../features/clients/presentation/bloc/client_form_bloc.dart';

// Warehouse feature
import '../../features/warehouse_documents/data/datasources/warehouse_remote_datasource.dart';
import '../../features/warehouse_documents/data/repositories/warehouse_repository_impl.dart';
import '../../features/warehouse_documents/domain/repositories/warehouse_repository.dart';
import '../../features/warehouse_documents/domain/usecases/get_warehouse_documents_usecase.dart';
import '../../features/warehouse_documents/domain/usecases/create_warehouse_document_usecase.dart';
import '../../features/warehouse_documents/presentation/bloc/warehouse_docs_bloc.dart';
import '../../features/warehouse_documents/presentation/bloc/warehouse_form_bloc.dart';

// Dashboard feature
import '../../features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart';

// Settings feature
import '../../features/settings/data/datasources/settings_remote_datasource.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/change_password_usecase.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';

// Products Stock feature
import '../../features/products_stock/data/datasources/products_stock_remote_datasource.dart';
import '../../features/products_stock/data/repositories/products_stock_repository_impl.dart';
import '../../features/products_stock/domain/repositories/products_stock_repository.dart';
import '../../features/products_stock/domain/usecases/get_stock_variants_usecase.dart';
import '../../features/products_stock/presentation/bloc/products_stock_bloc.dart';

// Orders feature
import '../../features/orders/data/datasources/order_remote_datasource.dart';
import '../../features/orders/data/repositories/order_repository_impl.dart';
import '../../features/orders/domain/repositories/order_repository.dart';
import '../../features/orders/domain/usecases/get_orders_usecase.dart';
import '../../features/orders/domain/usecases/create_order_usecase.dart';
import '../../features/orders/domain/usecases/update_order_usecase.dart';
import '../../features/orders/presentation/bloc/orders_bloc.dart';
import '../../features/orders/presentation/bloc/order_form_bloc.dart';

// Production feature
import '../../features/production/data/datasources/production_batch_remote_datasource.dart';
import '../../features/production/data/datasources/defect_document_remote_datasource.dart';
import '../../features/production/data/repositories/production_batch_repository_impl.dart';
import '../../features/production/domain/repositories/production_batch_repository.dart';
import '../../features/production/domain/usecases/get_production_batches_usecase.dart';
import '../../features/production/domain/usecases/get_production_batch_usecase.dart';
import '../../features/production/domain/usecases/get_production_batch_item_usecase.dart';
import '../../features/production/domain/usecases/create_production_batch_usecase.dart';
import '../../features/production/domain/usecases/update_production_batch_usecase.dart';
import '../../features/production/presentation/bloc/production_batches_bloc.dart';
import '../../features/production/presentation/bloc/production_batch_form_bloc.dart';

// Employees
import '../../features/employees/data/datasources/employee_remote_datasource.dart';
import '../../features/employees/data/repositories/employee_repository_impl.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/employees/domain/usecases/get_employees_usecase.dart';
import '../../features/employees/domain/usecases/create_employee_usecase.dart';
import '../../features/employees/domain/usecases/update_employee_usecase.dart';
import '../../features/employees/domain/usecases/delete_employee_usecase.dart';
import '../../features/employees/presentation/bloc/employees_bloc.dart';
import '../../features/employees/presentation/bloc/employee_form_bloc.dart';

// Labeling feature
import '../../features/labeling/data/datasources/labeling_remote_datasource.dart';
import '../../features/labeling/data/repositories/labeling_repository_impl.dart';
import '../../features/labeling/domain/repositories/labeling_repository.dart';
import '../../features/labeling/presentation/bloc/labeling_bloc.dart';

// Scanner feature
import '../../features/scanner/data/datasources/scanner_remote_datasource.dart';
import '../../features/scanner/data/repositories/scanner_repository_impl.dart';
import '../../features/scanner/domain/repositories/scanner_repository.dart';
import '../../features/scanner/presentation/bloc/scanner_bloc.dart';

// Shipments feature
import '../../features/shipments/data/datasources/shipment_remote_datasource.dart';
import '../../features/shipments/data/repositories/shipment_repository_impl.dart';
import '../../features/shipments/domain/repositories/shipment_repository.dart';
import '../../features/shipments/domain/usecases/get_shipments_usecase.dart';
import '../../features/shipments/domain/usecases/create_shipment_usecase.dart';
import '../../features/shipments/domain/usecases/get_orders_for_shipment_usecase.dart';
import '../../features/shipments/presentation/bloc/shipments_bloc.dart';
import '../../features/shipments/presentation/bloc/shipment_form_bloc.dart';

// Payments feature
import '../../features/payments/data/datasources/payment_remote_datasource.dart';
import '../../features/payments/data/repositories/payment_repository_impl.dart';
import '../../features/payments/domain/repositories/payment_repository.dart';
import '../../features/payments/domain/usecases/get_payments_usecase.dart';
import '../../features/payments/domain/usecases/create_payment_usecase.dart';
import '../../features/payments/domain/usecases/delete_payment_usecase.dart';
import '../../features/payments/presentation/bloc/payments_bloc.dart';
import '../../features/payments/presentation/bloc/payment_form_bloc.dart';

// Product Attributes feature
import '../../features/product_attributes/data/datasources/product_attributes_remote_datasource.dart';
import '../../features/product_attributes/data/repositories/product_attributes_repository_impl.dart';
import '../../features/product_attributes/domain/repositories/product_attributes_repository.dart';
import '../../features/product_attributes/domain/usecases/load_product_attributes_usecase.dart';
import '../../features/product_attributes/domain/usecases/color_usecases.dart';
import '../../features/product_attributes/domain/usecases/product_type_usecases.dart';
import '../../features/product_attributes/domain/usecases/product_quality_usecases.dart';
import '../../features/product_attributes/domain/usecases/product_size_usecases.dart';
import '../../features/product_attributes/presentation/bloc/product_attributes_bloc.dart';

// Debits feature
import '../../features/debits/data/datasources/debit_remote_datasource.dart';
import '../../features/debits/data/repositories/debit_repository_impl.dart';
import '../../features/debits/domain/repositories/debit_repository.dart';
import '../../features/debits/domain/usecases/get_client_debits_usecase.dart';
import '../../features/debits/domain/usecases/get_client_debit_ledger_usecase.dart';
import '../../features/debits/presentation/bloc/debits_bloc.dart';
import '../../features/debits/presentation/bloc/debit_ledger_bloc.dart';

// Raw Materials feature
import '../../features/raw_materials/data/datasources/raw_material_remote_datasource.dart';
import '../../features/raw_materials/data/repositories/raw_material_repository_impl.dart';
import '../../features/raw_materials/domain/repositories/raw_material_repository.dart';
import '../../features/raw_materials/domain/usecases/get_raw_materials_usecase.dart';
import '../../features/raw_materials/domain/usecases/create_raw_material_usecase.dart';
import '../../features/raw_materials/domain/usecases/store_batch_movement_usecase.dart';
import '../../features/raw_materials/presentation/bloc/raw_materials_bloc.dart';
import '../../features/raw_materials/presentation/bloc/raw_material_form_bloc.dart';
import '../../features/raw_materials/presentation/bloc/batch_movement_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ─── External ────────────────────────────────────────────────────────────
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(
      mOptions: MacOsOptions(useDataProtectionKeyChain: false),
    ),
  );
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // ─── Core ─────────────────────────────────────────────────────────────────
  sl.registerLazySingleton<TokenStorage>(
    () => SecureTokenStorage(sl<FlutterSecureStorage>()),
  );
  sl.registerLazySingleton<AuthInterceptor>(
    () => AuthInterceptor(sl<TokenStorage>()),
  );
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(authInterceptor: sl<AuthInterceptor>()),
  );
  sl.registerLazySingleton<Dio>(() => sl<ApiClient>().dio);
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl<Connectivity>()),
  );
  sl.registerLazySingleton<AppRouter>(() => AppRouter(sl<TokenStorage>()));

  // ─── Auth Feature ─────────────────────────────────────────────────────────
  // Datasources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl<Dio>()),
  );
  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl<AuthRemoteDataSource>(),
      tokenStorage: sl<TokenStorage>(),
    ),
  );
  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => LogoutUseCase(sl<AuthRepository>()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl<AuthRepository>()));
  // BLoC — singleton so state is shared across the app (avoids redundant network calls)
  sl.registerLazySingleton(
    () => AuthBloc(
      loginUseCase: sl<LoginUseCase>(),
      logoutUseCase: sl<LogoutUseCase>(),
      getCurrentUserUseCase: sl<GetCurrentUserUseCase>(),
    ),
  );

  // ─── Products Feature ──────────────────────────────────────────────────────
  // Datasource
  sl.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSourceImpl(sl<Dio>()),
  );
  // Repository
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(remoteDataSource: sl<ProductRemoteDataSource>()),
  );
  // Use cases
  sl.registerLazySingleton(() => GetProductsUseCase(sl<ProductRepository>()));
  sl.registerLazySingleton(() => GetProductTypesUseCase(sl<ProductRepository>()));
  sl.registerLazySingleton(() => GetProductQualitiesUseCase(sl<ProductRepository>()));
  sl.registerLazySingleton(() => GetProductSizesUseCase(sl<ProductRepository>()));
  sl.registerLazySingleton(() => CreateProductUseCase(sl<ProductRepository>()));
  sl.registerLazySingleton(() => UpdateProductUseCase(sl<ProductRepository>()));
  sl.registerLazySingleton(() => DeleteProductUseCase(sl<ProductRepository>()));
  sl.registerLazySingleton(() => CreateProductColorUseCase(sl<ProductRepository>()));
  sl.registerLazySingleton(() => DeleteProductColorUseCase(sl<ProductRepository>()));
  sl.registerLazySingleton(() => GetColorsUseCase(sl<ProductRepository>()));
  // BLoCs
  sl.registerFactory(
    () => ProductsBloc(
      getProductsUseCase: sl<GetProductsUseCase>(),
      updateProductUseCase: sl<UpdateProductUseCase>(),
      deleteProductUseCase: sl<DeleteProductUseCase>(),
    ),
  );
  sl.registerFactory(
    () => ProductFormBloc(
      createProductUseCase: sl<CreateProductUseCase>(),
      updateProductUseCase: sl<UpdateProductUseCase>(),
      getProductTypesUseCase: sl<GetProductTypesUseCase>(),
      getProductQualitiesUseCase: sl<GetProductQualitiesUseCase>(),
      getColorsUseCase: sl<GetColorsUseCase>(),
    ),
  );
  sl.registerFactory(
    () => ProductColorFormBloc(
      getColorsUseCase: sl<GetColorsUseCase>(),
      createProductColorUseCase: sl<CreateProductColorUseCase>(),
    ),
  );

  // ─── Clients Feature ──────────────────────────────────────────────────────
  sl.registerLazySingleton<ClientRemoteDataSource>(
    () => ClientRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<ClientRepository>(
    () => ClientRepositoryImpl(remoteDataSource: sl<ClientRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => GetClientsUseCase(sl<ClientRepository>()));
  sl.registerLazySingleton(() => CreateClientUseCase(sl<ClientRepository>()));
  sl.registerLazySingleton(() => UpdateClientUseCase(sl<ClientRepository>()));
  sl.registerLazySingleton(() => DeleteClientUseCase(sl<ClientRepository>()));
  sl.registerFactory(
    () => ClientsBloc(
      getClientsUseCase: sl<GetClientsUseCase>(),
      deleteClientUseCase: sl<DeleteClientUseCase>(),
    ),
  );
  sl.registerFactory(
    () => ClientFormBloc(
      createClientUseCase: sl<CreateClientUseCase>(),
      updateClientUseCase: sl<UpdateClientUseCase>(),
    ),
  );

  // ─── Warehouse Feature ─────────────────────────────────────────────────────
  sl.registerLazySingleton<WarehouseRemoteDataSource>(
    () => WarehouseRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<WarehouseRepository>(
    () => WarehouseRepositoryImpl(remoteDataSource: sl<WarehouseRemoteDataSource>()),
  );
  sl.registerLazySingleton(
    () => GetWarehouseDocumentsUseCase(sl<WarehouseRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateWarehouseDocumentUseCase(sl<WarehouseRepository>()),
  );
  sl.registerFactory(
    () => WarehouseDocsBloc(
      getWarehouseDocumentsUseCase: sl<GetWarehouseDocumentsUseCase>(),
    ),
  );
  sl.registerFactory(
    () => WarehouseFormBloc(
      createWarehouseDocumentUseCase: sl<CreateWarehouseDocumentUseCase>(),
    ),
  );

  // ─── Orders Feature ────────────────────────────────────────────────────────
  sl.registerLazySingleton<OrderRemoteDataSource>(
    () => OrderRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(remoteDataSource: sl<OrderRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => GetOrdersUseCase(sl<OrderRepository>()));
  sl.registerLazySingleton(() => CreateOrderUseCase(sl<OrderRepository>()));
  sl.registerLazySingleton(() => UpdateOrderUseCase(sl<OrderRepository>()));
  sl.registerFactory(
    () => OrdersBloc(getOrdersUseCase: sl<GetOrdersUseCase>()),
  );
  sl.registerFactory(
    () => OrderFormBloc(
      createOrderUseCase: sl<CreateOrderUseCase>(),
      updateOrderUseCase: sl<UpdateOrderUseCase>(),
    ),
  );

  // ─── Production Feature ────────────────────────────────────────────────────
  sl.registerLazySingleton<ProductionBatchRemoteDataSource>(
    () => ProductionBatchRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<DefectDocumentRemoteDataSource>(
    () => DefectDocumentRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<ProductionBatchRepository>(
    () => ProductionBatchRepositoryImpl(
        remoteDataSource: sl<ProductionBatchRemoteDataSource>()),
  );
  sl.registerLazySingleton(
    () => GetProductionBatchesUseCase(sl<ProductionBatchRepository>()),
  );
  sl.registerLazySingleton(
    () => GetProductionBatchUseCase(sl<ProductionBatchRepository>()),
  );
  sl.registerLazySingleton(
    () => GetProductionBatchItemUseCase(sl<ProductionBatchRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateProductionBatchUseCase(sl<ProductionBatchRepository>()),
  );
  sl.registerLazySingleton(
    () => UpdateProductionBatchUseCase(sl<ProductionBatchRepository>()),
  );
  sl.registerFactory(
    () => ProductionBatchesBloc(
      getProductionBatchesUseCase: sl<GetProductionBatchesUseCase>(),
    ),
  );
  sl.registerFactory(
    () => ProductionBatchFormBloc(
      createProductionBatchUseCase: sl<CreateProductionBatchUseCase>(),
      updateProductionBatchUseCase: sl<UpdateProductionBatchUseCase>(),
    ),
  );

  // Employees
  sl.registerLazySingleton<EmployeeRemoteDataSource>(
    () => EmployeeRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<EmployeeRepository>(
    () => EmployeeRepositoryImpl(remoteDataSource: sl<EmployeeRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => GetEmployeesUseCase(sl<EmployeeRepository>()));
  sl.registerLazySingleton(() => CreateEmployeeUseCase(sl<EmployeeRepository>()));
  sl.registerLazySingleton(() => UpdateEmployeeUseCase(sl<EmployeeRepository>()));
  sl.registerLazySingleton(() => DeleteEmployeeUseCase(sl<EmployeeRepository>()));
  sl.registerFactory(
    () => EmployeesBloc(
      getEmployeesUseCase: sl<GetEmployeesUseCase>(),
      deleteEmployeeUseCase: sl<DeleteEmployeeUseCase>(),
    ),
  );
  sl.registerFactory(
    () => EmployeeFormBloc(
      createEmployeeUseCase: sl<CreateEmployeeUseCase>(),
      updateEmployeeUseCase: sl<UpdateEmployeeUseCase>(),
    ),
  );

  // ─── Labeling Feature ─────────────────────────────────────────────────────
  sl.registerLazySingleton<LabelingRemoteDataSource>(
    () => LabelingRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<LabelingRepository>(
    () => LabelingRepositoryImpl(remoteDataSource: sl<LabelingRemoteDataSource>()),
  );
  sl.registerFactory(
    () => LabelingBloc(repository: sl<LabelingRepository>()),
  );

  // ─── Scanner Feature ──────────────────────────────────────────────────────
  sl.registerLazySingleton<ScannerRemoteDataSource>(
    () => ScannerRemoteDataSourceImpl(dio: sl<Dio>()),
  );
  sl.registerLazySingleton<ScannerRepository>(
    () => ScannerRepositoryImpl(remoteDataSource: sl<ScannerRemoteDataSource>()),
  );
  sl.registerFactory(
    () => ScannerBloc(repository: sl<ScannerRepository>()),
  );

  // ─── Shipments Feature ─────────────────────────────────────────────────────
  sl.registerLazySingleton<ShipmentRemoteDataSource>(
    () => ShipmentRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<ShipmentRepository>(
    () => ShipmentRepositoryImpl(remoteDataSource: sl<ShipmentRemoteDataSource>()),
  );
  sl.registerLazySingleton(
    () => GetShipmentsUseCase(sl<ShipmentRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateShipmentUseCase(sl<ShipmentRepository>()),
  );
  sl.registerLazySingleton(
    () => GetOrdersForShipmentUseCase(sl<ShipmentRepository>()),
  );
  sl.registerFactory(
    () => ShipmentsBloc(getShipmentsUseCase: sl<GetShipmentsUseCase>()),
  );
  sl.registerFactory(
    () => ShipmentFormBloc(createShipmentUseCase: sl<CreateShipmentUseCase>()),
  );
  sl.registerLazySingleton<DashboardRemoteDataSource>(
    () => DashboardRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(remoteDataSource: sl<DashboardRemoteDataSource>()),
  );
  sl.registerLazySingleton(
    () => GetDashboardStatsUseCase(sl<DashboardRepository>()),
  );

  // ─── Settings Feature ──────────────────────────────────────────────────────
  sl.registerLazySingleton<SettingsRemoteDataSource>(
    () => SettingsRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<SettingsRepository>(
    () => SettingsRepositoryImpl(remoteDataSource: sl<SettingsRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => ChangePasswordUseCase(sl<SettingsRepository>()));
  sl.registerFactory(
    () => SettingsBloc(changePasswordUseCase: sl<ChangePasswordUseCase>()),
  );

  // ─── Products Stock Feature ───────────────────────────────────────────────
  sl.registerLazySingleton<ProductsStockRemoteDataSource>(
    () => ProductsStockRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<ProductsStockRepository>(
    () => ProductsStockRepositoryImpl(remoteDataSource: sl<ProductsStockRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => GetStockVariantsUseCase(sl<ProductsStockRepository>()));
  sl.registerFactory(
    () => ProductsStockBloc(getStockVariantsUseCase: sl<GetStockVariantsUseCase>()),
  );

  // ─── Payments Feature ─────────────────────────────────────────────────────
  sl.registerLazySingleton<PaymentRemoteDataSource>(
    () => PaymentRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<PaymentRepository>(
    () => PaymentRepositoryImpl(remoteDataSource: sl<PaymentRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => GetPaymentsUseCase(sl<PaymentRepository>()));
  sl.registerLazySingleton(() => CreatePaymentUseCase(sl<PaymentRepository>()));
  sl.registerLazySingleton(() => DeletePaymentUseCase(sl<PaymentRepository>()));
  sl.registerFactory(
    () => PaymentsBloc(
      getPaymentsUseCase: sl<GetPaymentsUseCase>(),
      deletePaymentUseCase: sl<DeletePaymentUseCase>(),
    ),
  );
  sl.registerFactory(
    () => PaymentFormBloc(createPaymentUseCase: sl<CreatePaymentUseCase>()),
  );

  // ─── Debits Feature ───────────────────────────────────────────────────────
  sl.registerLazySingleton<DebitRemoteDataSource>(
    () => DebitRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<DebitRepository>(
    () => DebitRepositoryImpl(remoteDataSource: sl<DebitRemoteDataSource>()),
  );
  sl.registerLazySingleton(
    () => GetClientDebitsUseCase(sl<DebitRepository>()),
  );
  sl.registerLazySingleton(
    () => GetClientDebitLedgerUseCase(sl<DebitRepository>()),
  );
  sl.registerFactory(
    () => DebitsBloc(getClientDebitsUseCase: sl<GetClientDebitsUseCase>()),
  );
  sl.registerFactory(
    () => DebitLedgerBloc(
      getClientDebitLedgerUseCase: sl<GetClientDebitLedgerUseCase>(),
    ),
  );

  // ─── Product Attributes Feature ───────────────────────────────────────────
  sl.registerLazySingleton<ProductAttributesRemoteDataSource>(
    () => ProductAttributesRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<ProductAttributesRepository>(
    () => ProductAttributesRepositoryImpl(
      remoteDataSource: sl<ProductAttributesRemoteDataSource>(),
    ),
  );
  sl.registerLazySingleton(
    () => LoadProductAttributesUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateColorUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => UpdateColorUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => DeleteColorUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateProductTypeUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => UpdateProductTypeUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => DeleteProductTypeUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateProductQualityUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => UpdateProductQualityUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => DeleteProductQualityUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateProductSizeUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => UpdateProductSizeUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerLazySingleton(
    () => DeleteProductSizeUseCase(sl<ProductAttributesRepository>()),
  );
  sl.registerFactory(
    () => ProductAttributesBloc(
      loadUseCase: sl<LoadProductAttributesUseCase>(),
      createColorUseCase: sl<CreateColorUseCase>(),
      updateColorUseCase: sl<UpdateColorUseCase>(),
      deleteColorUseCase: sl<DeleteColorUseCase>(),
      createProductTypeUseCase: sl<CreateProductTypeUseCase>(),
      updateProductTypeUseCase: sl<UpdateProductTypeUseCase>(),
      deleteProductTypeUseCase: sl<DeleteProductTypeUseCase>(),
      createProductQualityUseCase: sl<CreateProductQualityUseCase>(),
      updateProductQualityUseCase: sl<UpdateProductQualityUseCase>(),
      deleteProductQualityUseCase: sl<DeleteProductQualityUseCase>(),
      createProductSizeUseCase: sl<CreateProductSizeUseCase>(),
      updateProductSizeUseCase: sl<UpdateProductSizeUseCase>(),
      deleteProductSizeUseCase: sl<DeleteProductSizeUseCase>(),
    ),
  );

  // ─── Raw Materials Feature ────────────────────────────────────────────────
  sl.registerLazySingleton<RawMaterialRemoteDataSource>(
    () => RawMaterialRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<RawMaterialRepository>(
    () => RawMaterialRepositoryImpl(remoteDataSource: sl<RawMaterialRemoteDataSource>()),
  );
  sl.registerLazySingleton(
    () => GetRawMaterialsUseCase(sl<RawMaterialRepository>()),
  );
  sl.registerLazySingleton(
    () => CreateRawMaterialUseCase(sl<RawMaterialRepository>()),
  );
  sl.registerLazySingleton(
    () => StoreBatchMovementUseCase(sl<RawMaterialRepository>()),
  );
  sl.registerFactory(
    () => RawMaterialsBloc(
      getRawMaterialsUseCase: sl<GetRawMaterialsUseCase>(),
      repository: sl<RawMaterialRepository>(),
    ),
  );
  sl.registerFactory(
    () => RawMaterialFormBloc(
      createRawMaterialUseCase: sl<CreateRawMaterialUseCase>(),
    ),
  );
  sl.registerFactory(
    () => BatchMovementBloc(
      storeBatchMovementUseCase: sl<StoreBatchMovementUseCase>(),
    ),
  );
}
