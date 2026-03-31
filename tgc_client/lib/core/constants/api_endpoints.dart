class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Products
  static const String products = '/products';
  static String productById(int id) => '/products/$id';

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
}
