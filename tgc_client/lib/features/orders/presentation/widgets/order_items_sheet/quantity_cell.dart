import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/orders/presentation/widgets/order_form_controller.dart';

class QuantityCell extends StatefulWidget {
  final OrderFormController ctrl;
  final int colorId;
  final int sizeId;
  final int? edgeId;
  final bool enabled;
  final int rowIndex;
  final int columnIndex;
  final int totalRows;
  final int totalColumns;
  final void Function(int rowIndex, int columnIndex)? onNavigate;
  final FocusNode? focusNode;
  final void Function(bool hasFocus)? onFocusChanged;

  const QuantityCell({
    super.key,
    required this.ctrl,
    required this.colorId,
    required this.sizeId,
    this.edgeId,
    required this.enabled,
    required this.rowIndex,
    required this.columnIndex,
    required this.totalRows,
    required this.totalColumns,
    this.onNavigate,
    this.focusNode,
    this.onFocusChanged,
  });

  @override
  State<QuantityCell> createState() => _QuantityCellState();
}

class _QuantityCellState extends State<QuantityCell> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  // Stored as a field so it isn't recreated on every build (which would
  // re-register key-event listeners and disrupt routing after each rebuild).
  // canRequestFocus: false ensures this node is in the focus tree for key-event
  // bubbling only and can NEVER receive primary focus itself — prevents the
  // "two cells appear focused" glitch when columns are inserted/sorted.
  final FocusNode _keyboardListenerNode =
      FocusNode(skipTraversal: true, canRequestFocus: false);

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = widget.ctrl.matrixCellCtrl(widget.colorId, widget.sizeId, edgeId: widget.edgeId);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant QuantityCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update the cell controller if the cell identity changed.
    if (widget.colorId != oldWidget.colorId || widget.sizeId != oldWidget.sizeId || widget.edgeId != oldWidget.edgeId) {
      _controller = widget.ctrl.matrixCellCtrl(widget.colorId, widget.sizeId, edgeId: widget.edgeId);
    }
    // Update the focus node if the parent passed a new one (e.g. after
    // structural rebuild triggered by adding/sorting size columns).
    final newFocus = widget.focusNode;
    if (newFocus != null && newFocus != _focusNode) {
      _focusNode.removeListener(_onFocusChange);
      // Only dispose the old node if we owned it (no prop was provided before).
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = newFocus;
      _focusNode.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      // Capture controller reference now; guard with mounted so we never
      // apply a selection to a disposed or swapped controller.
      final ctrl = _controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ctrl != _controller) return;
        final text = ctrl.text;
        if (text.isNotEmpty) {
          ctrl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: text.length,
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
    _keyboardListenerNode.dispose();
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
        focusNode: _keyboardListenerNode,
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
