import '../../features/auth/domain/entities/user_entity.dart';
import '../router/app_routes.dart';

/// Role-based feature permissions
class RolePermissions {
  /// Check if user can access Products feature
  static bool canAccessProducts(UserEntity user) {
    return user.isAdmin || user.isProductManager;
  }

  /// Check if user can access Orders feature
  static bool canAccessOrders(UserEntity user) {
    return user.isAdmin || user.isOrderManager;
  }

  /// Check if user can access Production feature
  static bool canAccessProduction(UserEntity user) {
    return user.isAdmin || user.isProductionManager || user.isMachineManager;
  }

  /// Check if user can access Shipping feature
  static bool canAccessShipping(UserEntity user) {
    return user.isAdmin || user.isSalesManager;
  }

  /// Check if user can access Warehouse feature
  static bool canAccessWarehouse(UserEntity user) {
    return user.isAdmin || user.isWarehouseManager;
  }

  /// Check if user can access Stock feature
  static bool canAccessStock(UserEntity user) {
    return user.isAdmin || user.isWarehouseManager;
  }

  /// Check if user can access Clients feature
  static bool canAccessClients(UserEntity user) {
    return user.isAdmin || user.isOrderManager;
  }

  /// Check if user can access Debits/Accounting feature
  static bool canAccessDebits(UserEntity user) {
    return user.isAdmin;
  }

  /// Check if user can access Labeling feature
  static bool canAccessLabeling(UserEntity user) {
    return user.isAdmin || user.isLabelManager;
  }

  /// Check if user can access Employees feature
  static bool canAccessEmployees(UserEntity user) {
    return user.isAdmin;
  }

  /// Check if user can access Product Attributes feature
  static bool canAccessProductAttributes(UserEntity user) {
    return user.isAdmin || user.isProductManager;
  }

  /// Check if user can access Raw Materials Warehouse feature
  static bool canAccessRawMaterials(UserEntity user) {
    return user.isAdmin || user.isRawWarehouseManager;
  }

  /// Check if user can access Settings feature
  static bool canAccessSettings(UserEntity user) {
    return user.isAdmin;
  }

  /// Get list of accessible feature routes for a user
  static List<String> getAccessibleFeatures(UserEntity user) {
    final features = <String>[];

    if (canAccessProducts(user)) features.add(AppRoutes.productsName);
    if (canAccessOrders(user)) features.add(AppRoutes.ordersName);
    if (canAccessProduction(user)) features.add(AppRoutes.productionName);
    if (canAccessShipping(user)) features.add(AppRoutes.shippingName);
    if (canAccessWarehouse(user)) features.add(AppRoutes.warehouseName);
    if (canAccessStock(user)) features.add(AppRoutes.productsStockName);
    if (canAccessClients(user)) features.add(AppRoutes.clientsName);
    if (canAccessDebits(user)) features.add(AppRoutes.debitsName);
    if (canAccessLabeling(user)) features.add(AppRoutes.labelingName);
    if (canAccessEmployees(user)) features.add(AppRoutes.employeesName);
    if (canAccessProductAttributes(user)) {
      features.add(AppRoutes.productAttributesName);
    }
    if (canAccessRawMaterials(user)) features.add(AppRoutes.rawMaterialsName);
    if (canAccessSettings(user)) features.add(AppRoutes.settingsName);

    return features;
  }

  /// Check if user has access to only one feature
  static bool hasSingleFeatureAccess(UserEntity user) {
    return getAccessibleFeatures(user).length == 1;
  }

  /// Get the single accessible feature route name if user has only one
  static String? getSingleFeatureRoute(UserEntity user) {
    final features = getAccessibleFeatures(user);
    return features.length == 1 ? features.first : null;
  }
}
