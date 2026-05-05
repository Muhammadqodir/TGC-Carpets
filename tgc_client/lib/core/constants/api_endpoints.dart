class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String labelManagers = '/auth/label-managers';

  // Products
  static const String products = '/products';
  static String productById(int id) => '/products/$id';
  static const String productTypes = '/product-types';
  static String productTypeById(int id) => '/product-types/$id';
  static const String productSizes = '/product-sizes';
  static String productSizeById(int id) => '/product-sizes/$id';
  static const String productQualities = '/product-qualities';
  static String productQualityById(int id) => '/product-qualities/$id';
  static const String productColors = '/product-colors';
  static String productColorById(int id) => '/product-colors/$id';
  static const String colors = '/colors';
  static String colorById(int id) => '/colors/$id';
  static String colorUsage(int id) => '/colors/$id/usage';
  static String productTypeUsage(int id) => '/product-types/$id/usage';
  static String productQualityUsage(int id) => '/product-qualities/$id/usage';
  static String productSizeUsage(int id) => '/product-sizes/$id/usage';

  // Clients
  static const String clients = '/clients';
  static String clientById(int id) => '/clients/$id';

  // Warehouse Documents
  static const String warehouseDocuments = '/warehouse-documents';
  static String warehouseDocumentById(int id) => '/warehouse-documents/$id';

  // Stock
  static const String stock = '/stock';
  static const String stockVariants = '/stock/variants';
  static const String stockMovements = '/stock/movements';

  // Shipments
  static const String shipments = '/shipments';
  static String shipmentById(int id) => '/shipments/$id';
  static const String shipmentsOrdersForShipment = '/shipments/orders-for-shipment';
  static const String shipmentsLastPrice = '/shipments/last-price';

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
  static String productionBatchItemById(int batchId, int itemId) =>
      '/production-batches/$batchId/items/$itemId';
  static String productionBatchItemUpdate(int batchId, int itemId) =>
      '/production-batches/$batchId/items/$itemId';
  static String productionBatchItemPrintLabel(int batchId, int itemId) =>
      '/production-batches/$batchId/items/$itemId/print-label';
  static const String productionBatchOrderItems =
      '/production-batches-order-items';
  static const String labelingItems = '/production-batches-labeling-items';

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

  // Payments
  static const String payments = '/payments';
  static String paymentById(int id) => '/payments/$id';

  // Debits (client debit/credit ledger)
  static const String clientDebits = '/clients/debits';
  static String clientDebitLedger(int clientId) => '/clients/$clientId/debit-ledger';

  // Raw Materials Warehouse
  static const String rawMaterials = '/raw-materials';
  static String rawMaterialById(int id) => '/raw-materials/$id';
  static const String rawMaterialMovements = '/raw-materials/movements';
  static const String rawMaterialMovementsBatch = '/raw-materials/movements/batch';

  // App Updates — public endpoint, lives at /api/ (not /api/v1/)
  // Use AppConstants.publicApiUrl as base, not baseUrl.
  static const String appUpdatesLatest = '/app-updates/latest';
}
