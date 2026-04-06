class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Products
  static const String products = '/products';
  static String productById(int id) => '/products/$id';
  static const String productTypes = '/product-types';
  static const String productSizes = '/product-sizes';

  // Clients
  static const String clients = '/clients';
  static String clientById(int id) => '/clients/$id';

  // Warehouse Documents
  static const String warehouseDocuments = '/warehouse-documents';
  static String warehouseDocumentById(int id) => '/warehouse-documents/$id';

  // Stock
  static const String stock = '/stock';
  static const String stockMovements = '/stock/movements';

  // Sales
  static const String sales = '/sales';
  static String saleById(int id) => '/sales/$id';

  // Employees
  static const String employees = '/employees';
  static String employeeById(int id) => '/employees/$id';

  // Dashboard
  static const String dashboardStats = '/dashboard/stats';

  // Settings
  static const String changePassword = '/auth/change-password';
}
