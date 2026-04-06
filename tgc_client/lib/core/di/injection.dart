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
import '../../features/products/domain/usecases/create_product_usecase.dart';
import '../../features/products/presentation/bloc/products_bloc.dart';
import '../../features/products/presentation/bloc/product_form_bloc.dart';

// Clients feature
import '../../features/clients/data/datasources/client_remote_datasource.dart';
import '../../features/clients/data/repositories/client_repository_impl.dart';
import '../../features/clients/domain/repositories/client_repository.dart';
import '../../features/clients/domain/usecases/get_clients_usecase.dart';
import '../../features/clients/domain/usecases/create_client_usecase.dart';
import '../../features/clients/presentation/bloc/clients_bloc.dart';
import '../../features/clients/presentation/bloc/client_form_bloc.dart';

// Sales feature
import '../../features/sales/data/datasources/sale_remote_datasource.dart';
import '../../features/sales/data/repositories/sale_repository_impl.dart';
import '../../features/sales/domain/repositories/sale_repository.dart';
import '../../features/sales/domain/usecases/get_sales_usecase.dart';
import '../../features/sales/domain/usecases/create_sale_usecase.dart';
import '../../features/sales/presentation/bloc/sales_bloc.dart';
import '../../features/sales/presentation/bloc/sale_form_bloc.dart';

// Warehouse feature
import '../../features/warehouse/data/datasources/warehouse_remote_datasource.dart';
import '../../features/warehouse/data/repositories/warehouse_repository_impl.dart';
import '../../features/warehouse/domain/repositories/warehouse_repository.dart';
import '../../features/warehouse/domain/usecases/get_warehouse_documents_usecase.dart';
import '../../features/warehouse/domain/usecases/create_warehouse_document_usecase.dart';
import '../../features/warehouse/presentation/bloc/warehouse_docs_bloc.dart';
import '../../features/warehouse/presentation/bloc/warehouse_form_bloc.dart';

// Dashboard feature
import '../../features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import '../../features/dashboard/data/repositories/dashboard_repository_impl.dart';
import '../../features/dashboard/domain/repositories/dashboard_repository.dart';
import '../../features/dashboard/domain/usecases/get_dashboard_stats_usecase.dart';
import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';

// Settings feature
import '../../features/settings/data/datasources/settings_remote_datasource.dart';
import '../../features/settings/data/repositories/settings_repository_impl.dart';
import '../../features/settings/domain/repositories/settings_repository.dart';
import '../../features/settings/domain/usecases/change_password_usecase.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';

// Employees
import '../../features/employees/data/datasources/employee_remote_datasource.dart';
import '../../features/employees/data/repositories/employee_repository_impl.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/employees/domain/usecases/get_employees_usecase.dart';
import '../../features/employees/domain/usecases/create_employee_usecase.dart';
import '../../features/employees/presentation/bloc/employees_bloc.dart';
import '../../features/employees/presentation/bloc/employee_form_bloc.dart';

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
  // BLoC
  sl.registerFactory(
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
  sl.registerLazySingleton(() => CreateProductUseCase(sl<ProductRepository>()));
  // BLoCs
  sl.registerFactory(
    () => ProductsBloc(getProductsUseCase: sl<GetProductsUseCase>()),
  );
  sl.registerFactory(
    () => ProductFormBloc(
      createProductUseCase: sl<CreateProductUseCase>(),
      getProductTypesUseCase: sl<GetProductTypesUseCase>(),
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
  sl.registerFactory(
    () => ClientsBloc(getClientsUseCase: sl<GetClientsUseCase>()),
  );
  sl.registerFactory(
    () => ClientFormBloc(createClientUseCase: sl<CreateClientUseCase>()),
  );

  // ─── Sales Feature ────────────────────────────────────────────────────────
  sl.registerLazySingleton<SaleRemoteDataSource>(
    () => SaleRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<SaleRepository>(
    () => SaleRepositoryImpl(remoteDataSource: sl<SaleRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => GetSalesUseCase(sl<SaleRepository>()));
  sl.registerLazySingleton(() => CreateSaleUseCase(sl<SaleRepository>()));
  sl.registerFactory(
    () => SalesBloc(getSalesUseCase: sl<GetSalesUseCase>()),
  );
  sl.registerFactory(
    () => SaleFormBloc(createSaleUseCase: sl<CreateSaleUseCase>()),
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

  // Employees
  sl.registerLazySingleton<EmployeeRemoteDataSource>(
    () => EmployeeRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<EmployeeRepository>(
    () => EmployeeRepositoryImpl(remoteDataSource: sl<EmployeeRemoteDataSource>()),
  );
  sl.registerLazySingleton(() => GetEmployeesUseCase(sl<EmployeeRepository>()));
  sl.registerLazySingleton(() => CreateEmployeeUseCase(sl<EmployeeRepository>()));
  sl.registerFactory(
    () => EmployeesBloc(getEmployeesUseCase: sl<GetEmployeesUseCase>()),
  );
  sl.registerFactory(
    () => EmployeeFormBloc(createEmployeeUseCase: sl<CreateEmployeeUseCase>()),
  );

  // ─── Dashboard Feature ─────────────────────────────────────────────────────
  sl.registerLazySingleton<DashboardRemoteDataSource>(
    () => DashboardRemoteDataSourceImpl(sl<Dio>()),
  );
  sl.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(remoteDataSource: sl<DashboardRemoteDataSource>()),
  );
  sl.registerLazySingleton(
    () => GetDashboardStatsUseCase(sl<DashboardRepository>()),
  );
  sl.registerFactory(
    () => DashboardBloc(getDashboardStatsUseCase: sl<GetDashboardStatsUseCase>()),
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
}
