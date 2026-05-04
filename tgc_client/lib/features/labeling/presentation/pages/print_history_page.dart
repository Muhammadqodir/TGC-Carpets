import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/print_label_60_60.dart';
import 'package:usb_label_print/usb_label_print.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/services/print_history_service.dart';
import '../../domain/entities/print_history_entity.dart';

class PrintHistoryPage extends StatefulWidget {
  const PrintHistoryPage({
    super.key,
    required this.historyService,
  });

  final PrintHistoryService historyService;

  @override
  State<PrintHistoryPage> createState() => _PrintHistoryPageState();
}

class _PrintHistoryPageState extends State<PrintHistoryPage> {
  // ── Label config ──────────────────────────────────────────────────────────
  static const _config = LabelConfig.preset60x60;

  // ── Printer state ─────────────────────────────────────────────────────────
  List<String> _printers = [];
  String? _selectedPrinter;
  bool _isLoadingPrinters = false;

  // ── Render keys per variant id ────────────────────────────────────────────
  final Map<int, GlobalKey> _repaintKeys = {};

  // ── Current history items ─────────────────────────────────────────────────
  List<PrintHistoryEntity> _items = [];
  bool _isLoading = true;

  // ── Printing state ────────────────────────────────────────────────────────
  final Set<int> _printingItems = {};

  final _discoveryService = PrinterDiscoveryService();
  final _printerService = PrinterService();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadPrinters();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final items = await widget.historyService.getHistory();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
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

  GlobalKey _keyFor(int variantId) =>
      _repaintKeys.putIfAbsent(variantId, () => GlobalKey());

  Future<String?> _renderLabel(GlobalKey key) async {
    final renderer = LabelRenderer(key);
    return renderer.renderToPng(pixelRatio: 1.0);
  }

  void _deleteTempFile(String path) {
    try {
      File(path).deleteSync();
    } catch (_) {}
  }

  bool get _isPrintingPlatform => Platform.isMacOS || Platform.isWindows;

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

  Future<void> _onPrint(PrintHistoryEntity item) async {
    if (_isPrintingPlatform && !_assertPrinterSelected()) return;

    final key = _keyFor(item.variantId);
    setState(() => _printingItems.add(item.variantId));

    try {
      final path = await _renderLabel(key);
      if (path == null) {
        setState(() => _printingItems.remove(item.variantId));
        return;
      }

      try {
        if (_isPrintingPlatform) {
          await _printerService.printFile(
            filePath: path,
            printerName: _selectedPrinter!,
            config: _config,
          );
        } else {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(path, mimeType: 'image/png')],
              text: item.productName,
            ),
          );
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yorliq chop etildi'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } finally {
        _deleteTempFile(path);
      }
    } finally {
      setState(() => _printingItems.remove(item.variantId));
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tarixni tozalash'),
        content: const Text(
          'Chop etish tarixini butunlay tozalamoqchimisiz? Bu amalni bekor qilish mumkin emas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Tozalash'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.historyService.clearHistory();
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tarix tozalandi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8ECEF),
      appBar: AppBar(
        title: const Text('Chop etish tarixi'),
        titleSpacing: 0,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            strokeWidth: 2,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedDelete02,
                strokeWidth: 2,
              ),
              tooltip: 'Tarixni tozalash',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Main UI column ─────────────────────────────────────────
          Positioned.fill(
            child: Column(
              children: [
                if (_isPrintingPlatform)
                  _PrinterSelector(
                    printers: _printers,
                    selected: _selectedPrinter,
                    isLoading: _isLoadingPrinters,
                    onChanged: (v) => setState(() => _selectedPrinter = v),
                    onRefresh: _loadPrinters,
                  ),
                Expanded(child: _buildContent()),
              ],
            ),
          ),

          // ── Off-screen hidden labels for RepaintBoundary rendering ─
          ..._items.map((item) {
            final key = _keyFor(item.variantId);
            final barcodeValue = item.variantBarcode?.isNotEmpty == true
                ? item.variantBarcode!
                : 'TGC-VAR-${item.variantId.toString().padLeft(8, '0')}';
            final qrData = 'PB{${item.batchId}} VAR{${item.variantId}}';

            return Positioned(
              left: -5000,
              top: 0,
              child: SizedBox(
                width: _config.widthPx.toDouble(),
                height: _config.heightPx.toDouble(),
                child: RepaintBoundary(
                  key: key,
                  child: PrintLabel60(
                    config: _config,
                    productName: item.productName,
                    quality: item.qualityName,
                    type: item.productTypeName,
                    color: item.colorName,
                    sizeLabel:
                        item.sizeLength != null && item.sizeWidth != null
                            ? item.sizeLabel
                            : null,
                    barcodeValue: barcodeValue,
                    qrData: qrData,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedFileNotFound,
              size: 64,
              color: AppColors.textSecondary,
              strokeWidth: 1.5,
            ),
            const SizedBox(height: 16),
            Text(
              'Chop etish tarixi bo\'sh',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Yorliq chop etganingizdan so\'ng bu yerda ko\'rinadi',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                (constraints.maxWidth / 260).floor().clamp(1, 5);
            const spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                    crossAxisCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _items.map((item) {
                return SizedBox(
                  width: cardWidth,
                  child: _HistoryCard(
                    item: item,
                    isPrinting: _printingItems.contains(item.variantId),
                    isPrintPlatform: _isPrintingPlatform,
                    onPrint: () => _onPrint(item),
                  ),
                );
              }).toList(),
            );
          },
        ),
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
                    ? Text('Printer topilmadi',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary))
                    : DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selected,
                          isExpanded: true,
                          isDense: true,
                          items: printers
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodyMedium),
                                  ))
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

// ── History card ──────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.isPrinting,
    required this.isPrintPlatform,
    required this.onPrint,
  });

  final PrintHistoryEntity item;
  final bool isPrinting;
  final bool isPrintPlatform;
  final VoidCallback onPrint;

  String _formatPrintTime() {
    final date = DateTime.fromMillisecondsSinceEpoch(item.printedAt);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Hozirgina';
    if (diff.inHours < 1) return '${diff.inMinutes} daqiqa oldin';
    if (diff.inDays < 1) return '${diff.inHours} soat oldin';
    if (diff.inDays < 7) return '${diff.inDays} kun oldin';

    return '${date.day}.${date.month}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Variant image ──────────────────────────────────────────
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: item.colorImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: item.colorImageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFFF0F2F5),
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _PlaceholderImage(),
                      )
                    : _PlaceholderImage(),
              ),
              Positioned(
                child: AppBadge(
                  label: item.batchTitle ?? 'Batch #${item.batchId}',
                  color: AppColors.textPrimary,
                ),
              )
            ],
          ),
          // ── Info section ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.productName} | ${item.sizeLabel} | ${item.colorName?.toUpperCase() ?? '—'}',
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _InfoChips(item: item),
                const SizedBox(height: 8),
                // ── Print time ───────────────────────────────────────────
                Row(
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedClock01,
                      size: 14,
                      color: AppColors.textSecondary,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatPrintTime(),
                      style: textTheme.labelSmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // ── Reprint button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isPrinting ? null : onPrint,
                    icon: isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : HugeIcon(
                            icon: isPrintPlatform
                                ? HugeIcons.strokeRoundedPrinter
                                : HugeIcons.strokeRoundedShare01,
                            color: Colors.white,
                            strokeWidth: 2,
                            size: 18,
                          ),
                    label: Text(
                      isPrinting
                          ? 'Chop etilmoqda...'
                          : isPrintPlatform
                              ? 'Qayta chop etish'
                              : 'Qayta ulashish',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChips extends StatelessWidget {
  const _InfoChips({required this.item});
  final PrintHistoryEntity item;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (item.productTypeName != null) item.productTypeName!.toUpperCase(),
      if (item.qualityName != null) item.qualityName!.toUpperCase(),
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: parts
          .map(
            (p) => AppBadge(
              label: p,
              color: const Color(0xFFF0F2F5),
              textColor: AppColors.textPrimary,
            ),
          )
          .toList(),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F2F5),
      child: const Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedPrayerRug01,
          size: 48,
          color: AppColors.textSecondary,
          strokeWidth: 1.5,
        ),
      ),
    );
  }
}
