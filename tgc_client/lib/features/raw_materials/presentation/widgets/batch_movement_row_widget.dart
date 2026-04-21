import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/raw_material_entity.dart';

/// A single row in the batch-movement form.
///
/// The row holds a reference to the [RawMaterialEntity] and a
/// [TextEditingController] for the quantity field.
class BatchMovementRow {
  final RawMaterialEntity material;
  final TextEditingController qtyController;

  BatchMovementRow({required this.material})
      : qtyController = TextEditingController(text: '');

  void dispose() => qtyController.dispose();
}

/// Displays one material row inside the batch movement form.
class BatchMovementRowWidget extends StatelessWidget {
  final BatchMovementRow row;
  final VoidCallback onRemove;

  const BatchMovementRowWidget({
    super.key,
    required this.row,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.material.name,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                '${row.material.type} · ${_unitLabel(row.material.unit)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: row.qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
            ],
            decoration: InputDecoration(
              hintText: '0',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8)),
              suffixText: _unitLabel(row.material.unit),
            ),
            validator: (v) {
              final val = double.tryParse(v ?? '');
              if (val == null || val <= 0) return 'Miqdor kiriting';
              return null;
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline,
              color: AppColors.error, size: 20),
          onPressed: onRemove,
        ),
      ],
    );
  }

  String _unitLabel(String unit) => switch (unit) {
        'sqm'   => 'm²',
        'kg'    => 'kg',
        'piece' => 'dona',
        _       => unit,
      };
}
