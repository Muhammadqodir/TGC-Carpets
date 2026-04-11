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
  static const String productQualities = '/product-qualities';
  static const String productColors = '/product-colors';
  static String productColorById(int id) => '/product-colors/$id';
  static const String colors = '/colors';

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

  // Orders
  static const String orders = '/orders';
  static String orderById(int id) => '/orders/$id';

  // Machines
  static const String machines = '/machines';
  static String machineById(int id) => '/machines/$id';

  // Production Batches
  static const String productionBatches = '/production-batches';
  static String productionBatchById(int id) => '/production-batches/$id';
  static String productionBatchStart(int id) =>
      '/production-batches/$id/start';
  static String productionBatchComplete(int id) =>
      '/production-batches/$id/complete';
  static String productionBatchCancel(int id) =>
      '/production-batches/$id/cancel';
  static String productionBatchItemUpdate(int batchId, int itemId) =>
      '/production-batches/$batchId/items/$itemId';
  static const String productionBatchOrderItems =
      '/production-batches-order-items';

  // Product Variants
  static const String productVariants = '/product-variants';

  // Defect Documents
  static String defectDocuments(int batchId) =>
      '/production-batches/$batchId/defect-documents';
  static String defectDocumentById(int id) => '/defect-documents/$id';

  // Dashboard
  static const String dashboardStats = '/dashboard/stats';

  // Settings
  static const String changePassword = '/auth/change-password';
}
