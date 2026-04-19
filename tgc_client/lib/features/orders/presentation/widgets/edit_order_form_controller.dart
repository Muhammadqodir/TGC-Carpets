import '../../domain/entities/order_item_entity.dart';
import 'order_form_controller.dart';
import 'order_item_row.dart';

/// Form controller for "edit order".
///
/// Pre-populates the standard [items] list with rows backed by server IDs so
/// existing items appear in the same unified list as newly added rows.
/// Users can re-pick a product/color on any row, or just change the quantity.
class EditOrderFormController extends OrderFormController {
  EditOrderFormController({required List<OrderItemEntity> initialItems})
      : super(
          initialRows: initialItems
              .map(
                (item) => OrderItemRow(
                  prefilledColorId: item.productColorId,
                  prefilledProductName: item.productName,
                  prefilledColorName: item.colorName,
                  prefilledColorImageUrl: item.colorImageUrl,
                  prefilledQualityName: item.qualityName,
                  prefilledProductTypeName: item.productTypeName,
                  prefilledProductTypeId: item.productTypeId,
                  prefilledSizeLength: item.sizeLength,
                  prefilledSizeWidth: item.sizeWidth,
                  initialQuantity: item.quantity,
                ),
              )
              .toList(),
        );
}
