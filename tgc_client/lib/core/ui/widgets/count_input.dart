import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// Stepper-style integer input:  [−]  value  [+]
///
/// The value is held in a [TextEditingController] so it integrates
/// naturally with [Form] validation.  Pressing the step buttons syncs
/// the controller text and calls [onChanged].
///
/// Set [dense] = true for compact table/list rows (36 px height).
class CountInput extends StatelessWidget {
  const CountInput({
    super.key,
    required this.controller,
    this.min = 1,
    this.max,
    this.onChanged,
    this.validator,
    this.height = 36,
  });

  final TextEditingController controller;

  /// Minimum allowed value (inclusive). Defaults to 1.
  final int min;

  /// Maximum allowed value (inclusive). Unconstrained when null.
  final int? max;

  /// Called after a button press or manual text edit when the value changes.
  final VoidCallback? onChanged;

  /// Optional form validator forwarded to the inner [TextFormField].
  final String? Function(String?)? validator;

  //Height
  final double height;

  int get _current => int.tryParse(controller.text) ?? min;

  void _step(int delta) {
    final next = _current + delta;
    if (next < min) return;
    if (max != null && next > max!) return;
    controller.text = next.toString();
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Minus button ─────────────────────────────────────────────
          InkWell(
            onTap: () => _step(-1),
            child: SizedBox(
              width: height,
              child: Icon(
                Icons.remove_rounded,
                size: height * 0.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),

          // ── Vertical divider ─────────────────────────────────────────
          Container(width: 1, color: AppColors.divider),

          // ── Value field ───────────────────────────────────────────────
          Expanded(
            child: Container(
              height: height,
              alignment: Alignment.center,
              child: TextFormField(
                controller: controller,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  // In dense / table rows suppress the inline error text;
                  // the parent form's snackbar handles validation feedback.
                  errorStyle: const TextStyle(height: 0, fontSize: 0),
                ),
                onChanged: (_) => onChanged?.call(),
                validator: validator,
              ),
            ),
          ),

          // ── Vertical divider ─────────────────────────────────────────
          Container(width: 1, color: AppColors.divider),

          // ── Plus button ───────────────────────────────────────────────
          InkWell(
            onTap: () => _step(1),
            child: SizedBox(
              width: height,
              child: Icon(
                Icons.add_rounded,
                size: height * 0.5,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
