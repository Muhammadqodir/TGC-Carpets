import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_form_controller.dart';

class QuantityCell extends StatefulWidget {
  final OrderFormController ctrl;
  final int colorId;
  final int sizeId;
  final bool enabled;
  final int rowIndex;
  final int columnIndex;
  final int totalRows;
  final int totalColumns;
  final void Function(int rowIndex, int columnIndex)? onNavigate;
  final FocusNode? focusNode;

  const QuantityCell({
    super.key,
    required this.ctrl,
    required this.colorId,
    required this.sizeId,
    required this.enabled,
    required this.rowIndex,
    required this.columnIndex,
    required this.totalRows,
    required this.totalColumns,
    this.onNavigate,
    this.focusNode,
  });

  @override
  State<QuantityCell> createState() => _QuantityCellState();
}

class _QuantityCellState extends State<QuantityCell> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.ctrl.matrixCellCtrl(widget.colorId, widget.sizeId);
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Select all text when focused
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.text.isNotEmpty) {
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (widget.onNavigate == null) return;

    int newRow = widget.rowIndex;
    int newCol = widget.columnIndex;
    bool shouldNavigate = false;

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (newRow > 0) {
        newRow = widget.rowIndex - 1;
        shouldNavigate = true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (newRow < widget.totalRows - 1) {
        newRow = widget.rowIndex + 1;
        shouldNavigate = true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (newCol > 0) {
        newCol = widget.columnIndex - 1;
        shouldNavigate = true;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (newCol < widget.totalColumns - 1) {
        newCol = widget.columnIndex + 1;
        shouldNavigate = true;
      }
    }

    if (shouldNavigate) {
      widget.onNavigate!(newRow, newCol);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 40,
      child: KeyboardListener(
        focusNode: FocusNode(skipTraversal: true),
        onKeyEvent: _handleKeyEvent,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: widget.enabled
                ? AppColors.surface
                : AppColors.divider.withValues(alpha: 0.3),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide:
                  BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(5)),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            hintText: widget.enabled ? '—' : null,
            hintStyle: const TextStyle(color: AppColors.divider, fontSize: 13),
          ),
        ),
      ),
    );
  }
}
