import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:usb_label_print/usb_label_print.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../widget/print_label.dart';
import 'print_labels_args.dart';

class PrintLabelsPage extends StatefulWidget {
  final PrintLabelsArgs args;

  const PrintLabelsPage({super.key, required this.args});

  @override
  State<PrintLabelsPage> createState() => _PrintLabelsPageState();
}

class _PrintLabelsPageState extends State<PrintLabelsPage> {
  // ── Label config ────────────────────────────────────────────────────────────
  static const _config = LabelConfig.preset58x40;
  static const _labelAspect = 464.0 / 320.0; // widthPx / heightPx

  // ── Printer state ────────────────────────────────────────────────────────────
  List<String> _printers = [];
  String? _selectedPrinter;
  bool _isLoadingPrinters = false;

  // ── Print state ──────────────────────────────────────────────────────────────
  /// Index of the label being printed individually (null = none).
  int? _printingIndex;

  /// Whether bulk print is running.
  bool _isBulkPrinting = false;

  /// Current position being processed during bulk print (1-based, for UI).
  int _bulkProgress = 0;

  // ── Capture keys ─────────────────────────────────────────────────────────────
  /// One GlobalKey per label — attached to the RepaintBoundary for PNG capture.
  late final List<GlobalKey> _repaintKeys;

  // ── Services ─────────────────────────────────────────────────────────────────
  final _discoveryService = PrinterDiscoveryService();
  final _printerService = PrinterService();

  // ─────────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _repaintKeys = List.generate(widget.args.items.length, (_) => GlobalKey());
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    setState(() => _isLoadingPrinters = true);
    final printers = await _discoveryService.discoverPrinters();
    if (!mounted) return;
    setState(() {
      _printers = printers;
      _selectedPrinter = printers.isNotEmpty ? printers.first : null;
      _isLoadingPrinters = false;
    });
  }

  // ── Rendering ─────────────────────────────────────────────────────────────────

  Future<String?> _renderLabel(int index) async {
    final renderer = LabelRenderer(_repaintKeys[index]);
    return renderer.renderToPng(pixelRatio: 1.0);
  }

  // ── Single-label print ────────────────────────────────────────────────────────

  Future<void> _printSingle(int index) async {
    if (!_assertPrinterSelected()) return;

    setState(() => _printingIndex = index);
    try {
      final path = await _renderLabel(index);
      if (path != null) {
        await _printerService.printFile(
          filePath: path,
          printerName: _selectedPrinter!,
          config: _config,
        );
        _deleteTempFile(path);
      }
    } finally {
      if (mounted) setState(() => _printingIndex = null);
    }
  }

  // ── Bulk print ────────────────────────────────────────────────────────────────

  /// Prints labels in document order. Each position is printed [quantity] times
  /// (copies) before moving on to the next position.
  Future<void> _bulkPrint() async {
    if (!_assertPrinterSelected()) return;

    setState(() {
      _isBulkPrinting = true;
      _bulkProgress = 0;
    });

    try {
      for (int i = 0; i < widget.args.items.length; i++) {
        if (!mounted) break;
        setState(() => _bulkProgress = i + 1);

        final item = widget.args.items[i];
        final path = await _renderLabel(i);
        if (path == null) continue;

        await _printerService.printFile(
          filePath: path,
          printerName: _selectedPrinter!,
          config: _config,
          copies: item.quantity,
        );

        _deleteTempFile(path);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBulkPrinting = false;
          _bulkProgress = 0;
        });
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  bool _assertPrinterSelected() {
    if (_selectedPrinter != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Iltimos, avval printer tanlang.'),
        backgroundColor: AppColors.error,
      ),
    );
    return false;
  }

  void _deleteTempFile(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  bool get _isAnyPrinting => _isBulkPrinting || _printingIndex != null;

  void _closePage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: const Text('Yopish'),
        content: const Text(
          'Barcha yorliqlarni chop etib bo‘linganmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xa, tayyor!'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.go(AppRoutes.warehouse);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final totalQty = widget.args.items.fold(0, (s, i) => s + i.quantity);

    return Scaffold(
      backgroundColor: const Color(0xFFE8ECEF),
      appBar: AppBar(
        title: Text('Yorliqlar — Hujjat #${widget.args.documentId}'),
        titleSpacing: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            strokeWidth: 2,
          ),
          onPressed: _closePage,
        ),
      ),
      // ── Bottom: bulk print ──────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isAnyPrinting ? null : _bulkPrint,
                  icon: _isBulkPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const HugeIcon(
                          icon: HugeIcons.strokeRoundedPrinter,
                          color: Colors.white,
                          strokeWidth: 2,
                          size: 20,
                        ),
                  label: Text(
                    _isBulkPrinting
                        ? 'Chop etilmoqda... ($_bulkProgress / ${widget.args.items.length})'
                        : 'Barchasini chop etish  ($totalQty dona)',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _closePage,
                  label: Text('Tayyor!'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Printer selector ─────────────────────────────────────────────
          _PrinterSelector(
            printers: _printers,
            selected: _selectedPrinter,
            isLoading: _isLoadingPrinters,
            onChanged: (v) => setState(() => _selectedPrinter = v),
            onRefresh: _loadPrinters,
          ),
          // ── Label grid ────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount =
                      (constraints.maxWidth / 290).floor().clamp(2, 6);
                  final spacing = 12.0;
                  final cardWidth =
                      (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                          crossAxisCount;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: List.generate(
                      widget.args.items.length,
                      (i) => SizedBox(
                        width: cardWidth,
                        child: _LabelCard(
                          index: i,
                          item: widget.args.items[i],
                          config: _config,
                          labelAspect: _labelAspect,
                          repaintKey: _repaintKeys[i],
                          isPrinting: _printingIndex == i,
                          isBulkPrinting: _isBulkPrinting,
                          onPrint: () => _printSingle(i),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Printer selector ──────────────────────────────────────────────────────────

class _PrinterSelector extends StatelessWidget {
  const _PrinterSelector({
    required this.printers,
    required this.selected,
    required this.isLoading,
    required this.onChanged,
    required this.onRefresh,
  });

  final List<String> printers;
  final String? selected;
  final bool isLoading;
  final ValueChanged<String?> onChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedPrinter,
            size: 20,
            color: AppColors.textSecondary,
            strokeWidth: 1.5,
          ),
          const SizedBox(width: 10),
          Text('Printer:', style: textTheme.bodyMedium),
          const SizedBox(width: 12),
          Expanded(
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : printers.isEmpty
                    ? Text(
                        'Printer topilmadi',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      )
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selected,
                          isExpanded: true,
                          isDense: true,
                          items: printers
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodyMedium,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: onChanged,
                        ),
                      ),
          ),
          IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedReload,
              size: 20,
              strokeWidth: 2.5,
            ),
            tooltip: 'Printerlarni yangilash',
            onPressed: isLoading ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

// ── Label card ────────────────────────────────────────────────────────────────

class _LabelCard extends StatelessWidget {
  const _LabelCard({
    required this.index,
    required this.item,
    required this.config,
    required this.labelAspect,
    required this.repaintKey,
    required this.isPrinting,
    required this.isBulkPrinting,
    required this.onPrint,
  });

  final int index;
  final PrintLabelItem item;
  final LabelConfig config;
  final double labelAspect;
  final GlobalKey repaintKey;

  /// True while this specific label is being printed individually.
  final bool isPrinting;

  /// True while the bulk print job is running.
  final bool isBulkPrinting;

  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canPrint = !isPrinting && !isBulkPrinting;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label rendered at full px size, scaled down by FittedBox.
            // RepaintBoundary is inside FittedBox so its layout size is
            // widthPx × heightPx — toImage(pixelRatio: 1.0) captures
            // at full print resolution.
            AspectRatio(
              aspectRatio: labelAspect,
              child: FittedBox(
                fit: BoxFit.contain,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: SizedBox(
                    width: config.widthPx.toDouble(),
                    height: config.heightPx.toDouble(),
                    child: PrintLabel(
                      config: config,
                      productName: item.productName,
                      quality: item.quality,
                      type: item.type,
                      color: item.color,
                      sizeLabel: item.sizeLabel,
                      barcodeValue: item.barcodeValue,
                      qrData: item.qrData,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Item info ─────────────────────────────────────────────────
                      Text(
                        '${index + 1}. ${item.productName}',
                        style: textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.sizeLabel ?? '—'}  •  ${item.color ?? '—'}  •  ${item.quantity} dona',
                        style: textTheme.labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: canPrint ? onPrint : null,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const HugeIcon(
                              icon: HugeIcons.strokeRoundedPrinter,
                              size: 16,
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}
