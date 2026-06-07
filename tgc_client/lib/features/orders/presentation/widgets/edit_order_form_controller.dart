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
          initialRows: (List<OrderItemEntity>.from(initialItems)
                ..sort((a, b) {
                  final typeCmp =
                      (a.productTypeId ?? 0).compareTo(b.productTypeId ?? 0);
                  if (typeCmp != 0) return typeCmp;
                  final widthCmp =
                      (a.sizeWidth ?? 0).compareTo(b.sizeWidth ?? 0);
                  return widthCmp != 0
                      ? widthCmp
                      : (a.sizeLength ?? 0).compareTo(b.sizeLength ?? 0);
                }))
              .map(
                (item) => OrderItemRow(
                  prefilledColorId: item.productColorId,
                  prefilledSizeId: item.productSizeId,
                  prefilledEdgeId: item.productEdgeId,
                  prefilledProductName: item.productName,
                  prefilledColorName: item.colorName,
                  prefilledColorImageUrl: item.colorImageUrl,
                  prefilledQualityName: item.qualityName,
                  prefilledProductTypeName: item.productTypeName,
                  prefilledProductTypeId: item.productTypeId,
                  prefilledSizeLength: item.sizeLength,
                  prefilledSizeWidth: item.sizeWidth,
                  prefilledEdgeCode: item.edgeCode,
                  initialQuantity: item.quantity,
                ),
              )
              .toList(),
        ) {
    seedMatrixFromPrefill();
  }
}
