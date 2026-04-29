import 'package:flutter/material.dart';

class PriceInput extends StatelessWidget {
  const PriceInput({
    super.key,
    required this.priceCtrl,
    required this.onChanged,
    this.height = 35,
  });
  final TextEditingController priceCtrl;
  final VoidCallback onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: TextFormField(
        controller: priceCtrl,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
        ),
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          hintText: '0.00',
          prefixText: '\$ ',
        ),
        validator: (v) {
          final val = double.tryParse(v?.trim().replaceAll(',', '.') ?? '');
          if (val == null || val <= 0) {
            return 'Narx kiriting';
          }
          return null;
        },
        onChanged: (_) => onChanged(),
      ),
    );
  }
}
