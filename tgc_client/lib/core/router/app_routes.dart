class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String splashName = 'splash';

  static const String login = '/login';
  static const String loginName = 'login';

  static const String dashboard = '/dashboard';
  static const String dashboardName = 'dashboard';

  static const String products = '/products';
  static const String productsName = 'products';

  static const String addProduct = '/products/add';
  static const String addProductName = 'addProduct';

  static const String clients = '/clients';
  static const String clientsName = 'clients';

  static const String addClient = '/clients/add';
  static const String addClientName = 'addClient';

  static const String warehouse = '/warehouse';
  static const String warehouseName = 'warehouse';

  static const String addWarehouseDocument = '/warehouse/add';
  static const String addWarehouseDocumentName = 'addWarehouseDocument';

  static const String warehouseDocumentPreview = '/warehouse/preview';
  static const String warehouseDocumentPreviewName = 'warehouseDocumentPreview';

  static const String printLabels     = '/warehouse/print-labels';
  static const String printLabelsName = 'printLabels';

  static const String shipping = '/shipping';
  static const String shippingName = 'shipping';

  static const String addShipping = '/shipping/add';
  static const String addShippingName = 'addShipping';

  static const String employees     = '/employees';
  static const String employeesName = 'employees';

  static const String addEmployee     = '/employees/add';
  static const String addEmployeeName = 'addEmployee';

  static const String editEmployee     = '/employees/edit';
  static const String editEmployeeName = 'editEmployee';

  static const String settings     = '/settings';
  static const String settingsName = 'settings';

  static const String orders     = '/orders';
  static const String ordersName = 'orders';

  static const String addOrder     = '/orders/add';
  static const String addOrderName = 'addOrder';

  static const String orderDetail     = '/orders/detail';
  static const String orderDetailName = 'orderDetail';

  static const String editOrder     = '/orders/edit';
  static const String editOrderName = 'editOrder';

  static const String production             = '/production';
  static const String productionName         = 'production';

  static const String addProductionBatch     = '/production/add';
  static const String addProductionBatchName = 'addProductionBatch';

  static const String productionBatchDetail     = '/production/detail';
  static const String productionBatchDetailName = 'productionBatchDetail';

  static const String editProductionBatch     = '/production/edit';
  static const String editProductionBatchName = 'editProductionBatch';

  static const String defectDocumentForm     = '/production/defect';
  static const String defectDocumentFormName = 'defectDocumentForm';

  static const String labeling     = '/labeling';
  static const String labelingName = 'labeling';

  static const String scanner     = '/scanner';
  static const String scannerName = 'scanner';

  static const String productsStock     = '/products-stock';
  static const String productsStockName = 'productsStock';

  static const String rawMaterials     = '/raw-materials';
  static const String rawMaterialsName = 'rawMaterials';

  static const String addRawMaterial     = '/raw-materials/add';
  static const String addRawMaterialName = 'addRawMaterial';

  static const String rawMaterialBatchMovement     = '/raw-materials/batch-movement';
  static const String rawMaterialBatchMovementName = 'rawMaterialBatchMovement';

  static const String payments     = '/payments';
  static const String paymentsName = 'payments';

  static const String addPayment     = '/payments/add';
  static const String addPaymentName = 'addPayment';

  static const String debits     = '/debits';
  static const String debitsName = 'debits';

  static const String productAttributes     = '/product-attributes';
  static const String productAttributesName = 'productAttributes';

  static const String clientDebitDetail     = '/debits/detail';
  static const String clientDebitDetailName = 'clientDebitDetail';

  static const String shipmentInvoice     = '/shipping/invoice';
  static const String shipmentInvoiceName = 'shipmentInvoice';
}
