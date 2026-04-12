import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:usb_label_print/usb_label_print.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../widget/print_label.dart';
import '../../domain/entities/labeling_item_entity.dart';
import '../bloc/labeling_bloc.dart';
import '../bloc/labeling_event.dart';
import '../bloc/labeling_state.dart';

class LabelingPage extends StatelessWidget {
  const LabelingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<LabelingBloc>(),
      child: BlocListener<LabelingBloc, LabelingState>(
        listenWhen: (_, s) => s is LabelingError,
        listener: (context, state) {
          if (state is LabelingError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        child: const _LabelingView(),
      ),
    );
  }
}

class _LabelingView extends StatefulWidget {
  const _LabelingView();

  @override
  State<_LabelingView> createState() => _LabelingViewState();
}

class _LabelingViewState extends State<_LabelingView> {
  // ── Label config ──────────────────────────────────────────────────────────
  static const _config = LabelConfig.preset58x40;

  // ── Printer state ─────────────────────────────────────────────────────────
  List<String> _printers = [];
  String? _selectedPrinter;
  bool _isLoadingPrinters = false;

  // ── Render keys per item id ────────────────────────────────────────────────
  final Map<int, GlobalKey> _repaintKeys = {};

  // ── Current items (mirrored from BLoC for hidden-label rendering) ─────────
  List<LabelingItemEntity> _items = [];

  final _discoveryService = PrinterDiscoveryService();
  final _printerService = PrinterService();

  @override
  void initState() {
    super.initState();
    context.read<LabelingBloc>().add(const LabelingLoadRequested());
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

  GlobalKey _keyFor(int itemId) =>
      _repaintKeys.putIfAbsent(itemId, () => GlobalKey());

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

  Future<void> _onPrint(LabelingItemEntity item) async {
    if (_isPrintingPlatform && !_assertPrinterSelected()) return;

    final key = _keyFor(item.id);
    // Dispatch to BLoC to mark item as printing / increment count on backend
    context.read<LabelingBloc>().add(
          LabelingPrintRequested(batchId: item.batchId, itemId: item.id),
        );

    final path = await _renderLabel(key);
    if (path == null) return;

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
    } finally {
      _deleteTempFile(path);
    }
  }

  Future<void> _refresh() async {
    context.read<LabelingBloc>().add(const LabelingRefreshRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LabelingBloc, LabelingState>(
      listener: (context, state) {
        if (state is LabelingLoaded) {
          setState(() => _items = state.items);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: const Color(0xFFE8ECEF),
          appBar: AppBar(
            title: const Text('Yorliqlash'),
            titleSpacing: 0,
            leading: IconButton(
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedArrowLeft01,
                strokeWidth: 2,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: Stack(
            // Clip.none ensures off-screen positioned labels are still painted
            // so that RepaintBoundary.toImage() can capture them.
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
                    Expanded(child: _buildContent(state)),
                  ],
                ),
              ),

              // ── Off-screen hidden labels for RepaintBoundary rendering ─
              // Positioned far off to the left. Stack's Clip.none ensures
              // they are still painted and capturable via toImage().
              ..._items.map((item) {
                final key = _keyFor(item.id);
                final barcodeValue = item.variantBarcode?.isNotEmpty == true
                    ? item.variantBarcode!
                    : 'TGC-VAR-${item.variantId.toString().padLeft(8, '0')}';
                final qrData = '${item.batchId}/${item.variantId}';

                return Positioned(
                  left: -5000,
                  top: 0,
                  child: SizedBox(
                    width: _config.widthPx.toDouble(),
                    height: _config.heightPx.toDouble(),
                    child: RepaintBoundary(
                      key: key,
                      child: PrintLabel(
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
      },
    );
  }

  Widget _buildContent(LabelingState state) {
    if (state is LabelingLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is LabelingError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _refresh,
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedReload,
                  color: Colors.white,
                  strokeWidth: 2,
                  size: 18,
                ),
                label: const Text('Qayta urinish'),
              ),
            ],
          ),
        ),
      );
    }

    if (state is LabelingLoaded && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
              size: 64,
              color: AppColors.textSecondary,
              strokeWidth: 1.5,
            ),
            const SizedBox(height: 16),
            Text(
              'Barcha mahsulotlar yorliqlangan!',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final items =
        state is LabelingLoaded ? state.items : <LabelingItemEntity>[];
    final printingItems =
        state is LabelingLoaded ? state.printingItems : <int, bool>{};

    // Group items by batchId while preserving insertion order
    final groups = <int, List<LabelingItemEntity>>{};
    for (final item in items) {
      groups.putIfAbsent(item.batchId, () => []).add(item);
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount =
                (constraints.maxWidth / 260).floor().clamp(1, 6);
            const spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                    crossAxisCount;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: groups.entries.map((entry) {
                final batchId = entry.key;
                final batchItems = entry.value;
                final batchTitle = batchItems.first.batchTitle ?? 'Batch #$batchId';

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Text(
                        batchTitle,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: batchItems.map((item) {
                        return SizedBox(
                          width: cardWidth,
                          child: _LabelingCard(
                            item: item,
                            isPrinting: printingItems[item.id] == true,
                            isPrintPlatform: _isPrintingPlatform,
                            onPrint: () => _onPrint(item),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
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

// ── Labeling card (big image + print button) ──────────────────────────────────

class _LabelingCard extends StatelessWidget {
  const _LabelingCard({
    required this.item,
    required this.isPrinting,
    required this.isPrintPlatform,
    required this.onPrint,
  });

  final LabelingItemEntity item;
  final bool isPrinting;
  final bool isPrintPlatform;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final remaining = item.remainingQuantity;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Big variant image ──────────────────────────────────────────
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
                // ── Progress bar ──────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.plannedQuantity > 0
                        ? item.producedQuantity / item.plannedQuantity
                        : 0,
                    minHeight: 6,
                    backgroundColor: AppColors.divider,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bajarildi: ${item.producedQuantity} / ${item.plannedQuantity}  •  Qoldi: $remaining',
                  style: textTheme.labelSmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                // ── Print button ──────────────────────────────────────────
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
                              ? 'Yorliq chop etish'
                              : 'Yorliq ulashish',
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
  final LabelingItemEntity item;

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
              color: Color(0xFFF0F2F5),
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
