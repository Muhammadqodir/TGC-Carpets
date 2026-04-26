import 'package:flutter/material.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_form_controller.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_items_sheet/summary_cell.dart';
import 'package:tgc_client/features/products/domain/entities/product_size_entity.dart';

class SizeSummaryColumn extends StatefulWidget {
  const SizeSummaryColumn({super.key, required this.ctrl, required this.size});

  final OrderFormController ctrl;
  final ProductSizeEntity size;

  @override
  State<SizeSummaryColumn> createState() => _SizeSummaryColumnState();
}

class _SizeSummaryColumnState extends State<SizeSummaryColumn> {
  final _watched = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    widget.ctrl.addListener(_onStructure);
    _subscribe();
  }

  void _subscribe() {
    for (final row in widget.ctrl.getUniqueItems()) {
      final colorId = row.selectedColor?.id ?? row.prefilledColorId;
      if (colorId == null) continue;
      final c = widget.ctrl.matrixCellCtrl(colorId, widget.size.id);
      c.addListener(_onValue);
      _watched.add(c);
    }
  }

  void _unsubscribe() {
    for (final c in _watched) {
      c.removeListener(_onValue);
    }
    _watched.clear();
  }

  void _onStructure() {
    _unsubscribe();
    _subscribe();
    setState(() {});
  }

  void _onValue() => setState(() {});

  @override
  void dispose() {
    widget.ctrl.removeListener(_onStructure);
    _unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = widget.ctrl.totalQtyForSize(widget.size.id);
    final totalM = (qty * widget.size.length) / 100.0;
    final totalSqm = (qty * widget.size.length * widget.size.width) / 10000.0;
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          SummaryCell(
            label: 'Uzunlik',
            value: '${totalM.toStringAsFixed(1)} m',
          ),
          SummaryCell(
            label: 'Maydon',
            value: '${totalSqm.toStringAsFixed(2)} m²',
          ),
        ],
      ),
    );
  }
}
