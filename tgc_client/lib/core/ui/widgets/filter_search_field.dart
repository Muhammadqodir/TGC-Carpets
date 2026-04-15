import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Reusable search text field for desktop filter bars.
///
/// Renders an outlined 38-height [TextField] with a search prefix icon.
/// Highlights with [AppColors.primary] border when focused.
class FilterSearchField extends StatelessWidget {
  const FilterSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Qidirish...',
    this.width = 220,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 38,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_outlined, size: 18),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
