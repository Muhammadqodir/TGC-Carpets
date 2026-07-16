import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tgc_client/core/ui/widgets/app_badge.dart';
import 'package:tgc_client/core/ui/widgets/app_thumbnail.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/labels/print_label_70_50.dart';
import 'package:tgc_client/features/labeling/presentation/widgets/labels/print_label_70_50_arab.dart';
import 'package:usb_label_print/usb_label_print.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/services/print_history_service.dart';
import '../widgets/client_filter_sidebar.dart';
import '../widgets/machine_filter_sidebar.dart';
import '../widgets/size_filter_sidebar.dart';
import '../../domain/entities/labeling_item_entity.dart';
import '../../domain/label_qr_format.dart';
import '../bloc/labeling_bloc.dart';
import '../bloc/labeling_event.dart';
import '../bloc/labeling_state.dart';
import 'print_history_page.dart';

// ── Shared preferences keys ─────────────────────────────────────────────────
const _kPrefLabelStyle = 'labeling_label_style';
const _kPrefLabelSize = 'labeling_label_size';
const _kPrefDpi = 'labeling_dpi';
const _kPrefPrinter = 'labeling_printer';

// ── Cached filter result ─────────────────────────────────────────────────────

class _FilterResult {
  const _FilterResult({
    this.displayedItems = const [],
    this.machineGroups = const {},
    this.clientGroups = const {},
    this.sizeGroups = const {},
  });

  final List<LabelingItemEntity> displayedItems;
  final Map<String, List<LabelingItemEntity>> machineGroups;
  final Map<String, List<LabelingItemEntity>> clientGroups;
  final Map<String, List<LabelingItemEntity>> sizeGroups;
}

// ── Label size options (all LabelConfig presets) ─────────────────────────────

enum _LabelSize {
  size80x50,
  size60x60,
  size58x40,
  size58x30,
  size40x30;

  String get label => switch (this) {
        _LabelSize.size80x50 => '80×50',
        _LabelSize.size60x60 => '60×60',
        _LabelSize.size58x40 => '58×40',
        _LabelSize.size58x30 => '58×30',
        _LabelSize.size40x30 => '40×30',
      };

  LabelConfig configWithDpi(int dpi) => switch (this) {
        _LabelSize.size80x50 => LabelConfig(widthMm: 78, heightMm: 50, dpi: dpi),
        _LabelSize.size60x60 => LabelConfig(widthMm: 58, heightMm: 60, dpi: dpi),
        _LabelSize.size58x40 => LabelConfig(widthMm: 58, heightMm: 40, dpi: dpi),
        _LabelSize.size58x30 => LabelConfig(widthMm: 58, heightMm: 30, dpi: dpi),
        _LabelSize.size40x30 => LabelConfig(widthMm: 40, heightMm: 30, dpi: dpi),
      };
}

// ── Label style options ──────────────────────────────────────────────────────

enum _LabelStyle {
  asosiy,
  asosiyArab;

  String get label => switch (this) {
        _LabelStyle.asosiy => 'Asosiy',
        _LabelStyle.asosiyArab => 'Asosiy arab',
      };
}

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
  // ── Label style ────────────────────────────────────────────────────────────
  _LabelStyle _labelStyle = _LabelStyle.asosiy;

  // ── Label size ─────────────────────────────────────────────────────────────
  _LabelSize _labelSize = _LabelSize.size80x50;

  // ── Print DPI ──────────────────────────────────────────────────────────────
  int _dpi = 203;

  LabelConfig get _config => _labelSize.configWithDpi(_dpi);

  // ── Printer state ─────────────────────────────────────────────────────────
  List<String> _printers = [];
  String? _selectedPrinter;
  bool _isLoadingPrinters = false;

  // ── Render keys per item id ────────────────────────────────────────────────
  final Map<int, GlobalKey> _repaintKeys = {};

  // ── Items currently being rendered off-screen (only while printing) ───────
  final Map<int, LabelingItemEntity> _renderingItems = {};

  // ── Tracks previous loaded count to detect when the list empties ──────────
  int _lastItemCount = 0;

  // ── Selected machine filter (null = show all) ──────────────────────────────
  String? _selectedMachine;

  // ── Selected client filter (null = show all) ─────────────────────────────
  String? _selectedClient;

  // ── Selected size filter (null = show all) ────────────────────────────────
  String? _selectedSize;

  // ── Cached filter computation ─────────────────────────────────────────────
  List<LabelingItemEntity> _cachedItems = const [];
  String? _cachedMachine;
  String? _cachedClient;
  String? _cachedSize;
  _FilterResult _filterResult = const _FilterResult();

  // ── Pagination ────────────────────────────────────────────────────────────
  int _currentPage = 0;

  final _discoveryService = PrinterDiscoveryService();
  final _printerService = PrinterService();
  final _historyService = sl<PrintHistoryService>();

  @override
  void initState() {
    super.initState();
    context.read<LabelingBloc>().add(const LabelingLoadRequested());
    _loadSettings().then((_) => _loadPrinters());
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final styleIndex = prefs.getInt(_kPrefLabelStyle);
    final sizeIndex = prefs.getInt(_kPrefLabelSize);
    final dpi = prefs.getInt(_kPrefDpi);
    final printer = prefs.getString(_kPrefPrinter);
    if (!mounted) return;
    setState(() {
      if (styleIndex != null && styleIndex < _LabelStyle.values.length) {
        _labelStyle = _LabelStyle.values[styleIndex];
      }
      if (sizeIndex != null && sizeIndex < _LabelSize.values.length) {
        _labelSize = _LabelSize.values[sizeIndex];
      }
      if (dpi != null) _dpi = dpi;
      if (printer != null) _selectedPrinter = printer;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPrefLabelStyle, _labelStyle.index);
    await prefs.setInt(_kPrefLabelSize, _labelSize.index);
    await prefs.setInt(_kPrefDpi, _dpi);
    if (_selectedPrinter != null) {
      await prefs.setString(_kPrefPrinter, _selectedPrinter!);
    } else {
      await prefs.remove(_kPrefPrinter);
    }
  }

  Future<void> _loadPrinters() async {
    setState(() => _isLoadingPrinters = true);
    final printers = await _discoveryService.discoverPrinters();
    if (!mounted) return;
    // Only override the persisted printer if the stored value is no longer
    // available in the discovered list, or if no printer was ever saved.
    setState(() {
      _printers = printers;
      if (printers.isNotEmpty &&
          (_selectedPrinter == null ||
              !printers.contains(_selectedPrinter))) {
        _selectedPrinter = printers.first;
        _saveSettings();
      }
      _isLoadingPrinters = false;
    });
  }

  // ── Filter computation (memoised) ──────────────────────────────────────────
  // Re-runs only when items list reference or an active filter changes.
  _FilterResult _computeFiltered(List<LabelingItemEntity> items) {
    if (identical(items, _cachedItems) &&
        _selectedMachine == _cachedMachine &&
        _selectedClient == _cachedClient &&
        _selectedSize == _cachedSize) {
      return _filterResult;
    }

    _cachedItems = items;
    _cachedMachine = _selectedMachine;
    _cachedClient = _selectedClient;
    _cachedSize = _selectedSize;

    final printableItems = items.where((item) => item.isTypePrintable).toList(growable: false);

    final machineGroups = <String, List<LabelingItemEntity>>{};
    for (final item in printableItems) {
      if (_selectedClient != null && (item.clientName ?? '—') != _selectedClient) continue;
      if (_selectedSize != null && item.sizeLabel != _selectedSize) continue;
      machineGroups.putIfAbsent(item.machineName ?? '—', () => []).add(item);
    }

    final clientGroups = <String, List<LabelingItemEntity>>{};
    for (final item in printableItems) {
      if (_selectedMachine != null && (item.machineName ?? '—') != _selectedMachine) continue;
      if (_selectedSize != null && item.sizeLabel != _selectedSize) continue;
      clientGroups.putIfAbsent(item.clientName ?? '—', () => []).add(item);
    }

    final sizeGroups = <String, List<LabelingItemEntity>>{};
    for (final item in printableItems) {
      if (_selectedMachine != null && (item.machineName ?? '—') != _selectedMachine) continue;
      if (_selectedClient != null && (item.clientName ?? '—') != _selectedClient) continue;
      sizeGroups.putIfAbsent(item.sizeLabel, () => []).add(item);
    }

    final displayed = printableItems.where((item) {
      if (_selectedMachine != null && (item.machineName ?? '—') != _selectedMachine) return false;
      if (_selectedClient != null && (item.clientName ?? '—') != _selectedClient) return false;
      if (_selectedSize != null && item.sizeLabel != _selectedSize) return false;
      return true;
    }).toList(growable: false);

    return _filterResult = _FilterResult(
      displayedItems: displayed,
      machineGroups: machineGroups,
      clientGroups: clientGroups,
      sizeGroups: sizeGroups,
    );
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

    // Dispatch to BLoC to mark item as printing / increment count on backend
    context.read<LabelingBloc>().add(
          LabelingPrintRequested(batchId: item.batchId, itemId: item.id),
        );

    try {
      // Add item to off-screen rendering map, wait for the frame to paint it
      if (mounted) setState(() => _renderingItems[item.id] = item);
      await WidgetsBinding.instance.endOfFrame;

      final key = _keyFor(item.id);
      final path = await _renderLabel(key);
      if (path == null) return; // finally cleans up

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

        // Save to print history after successful print
        await _historyService.addToHistory(item);
        // BLoC already removes fully-labeled items locally; no network refresh needed
      } finally {
        _deleteTempFile(path);
      }
    } finally {
      // Remove off-screen widget and re-enable button
      if (mounted) setState(() => _renderingItems.remove(item.id));
      context.read<LabelingBloc>().add(
            LabelingPrintCompleted(itemId: item.id),
          );
    }
  }

  void _showSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> refreshPrinters() async {
            setDialogState(() {});
            setState(() => _isLoadingPrinters = true);
            final printers = await _discoveryService.discoverPrinters();
            if (!mounted) return;
            setState(() {
              _printers = printers;
              if (printers.isNotEmpty &&
                  (_selectedPrinter == null ||
                      !printers.contains(_selectedPrinter))) {
                _selectedPrinter = printers.first;
              }
              _isLoadingPrinters = false;
            });
            _saveSettings();
            setDialogState(() {});
          }

          return AlertDialog(
            title: const Text('Sozlamalar'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [                  // ── Label size ───────────────────────────────────────────
                  Text(
                    'Yorliq o\'lchami',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<_LabelSize>(
                      value: _labelSize,
                      isExpanded: true,
                      isDense: true,
                      items: _LabelSize.values
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                s.label,
                                style: Theme.of(ctx).textTheme.bodyMedium,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _labelSize = v);
                        _saveSettings();
                        setDialogState(() {});
                      },
                    ),
                  ),
                  const SizedBox(height: 20),                  // ── Label style ──────────────────────────────────────
                  Text(
                    'Yorliq uslubi',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<_LabelStyle>(
                    segments: _LabelStyle.values
                        .map(
                          (s) => ButtonSegment<_LabelStyle>(
                            value: s,
                            label: Text(s.label),
                          ),
                        )
                        .toList(),
                    selected: {_labelStyle},
                    onSelectionChanged: (selected) {
                      setState(() => _labelStyle = selected.first);
                      _saveSettings();
                      setDialogState(() {});
                    },
                  ),
                  const SizedBox(height: 20),
                  // ── DPI ──────────────────────────────────────────────────
                  Text(
                    'Chop etish sifati (DPI)',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment<int>(value: 203, label: Text('203 DPI')),
                      ButtonSegment<int>(value: 300, label: Text('300 DPI')),
                    ],
                    selected: {_dpi},
                    onSelectionChanged: (selected) {
                      setState(() => _dpi = selected.first);
                      _saveSettings();
                      setDialogState(() {});
                    },
                  ),
                  // ── Label preview ────────────────────────────────────
                  const SizedBox(height: 20),
                  Text(
                    'Yorliq ko\'rinishi',
                    style: Theme.of(ctx).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 10),
                  ClipRect(
                    child: SizedBox(
                      width: double.infinity,
                      height: 340 /
                          (_config.widthPx / _config.heightPx),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: _config.widthPx.toDouble(),
                          height: _config.heightPx.toDouble(),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: getLabelWidget(
                              style: _labelStyle,
                              productName: '1568',
                              quality: 'Ronaldo',
                              type: 'Classic',
                              color: 'Beige',
                              sizeLabel: '200x300 R',
                              barcodeValue: 'TGC-00000001',
                              qrData: buildLabelQr(batchId: 1, itemId: 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_isPrintingPlatform) ...[
                    const SizedBox(height: 20),
                    // ── Printer ──────────────────────────────────────
                    Text(
                      'Printer',
                      style: Theme.of(ctx).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _isLoadingPrinters
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : _printers.isEmpty
                                  ? Text(
                                      'Printer topilmadi',
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              color: AppColors.textSecondary),
                                    )
                                  : DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedPrinter,
                                        isExpanded: true,
                                        isDense: true,
                                        items: _printers
                                            .map(
                                              (p) => DropdownMenuItem(
                                                value: p,
                                                child: Text(
                                                  p,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Theme.of(ctx)
                                                      .textTheme
                                                      .bodyMedium,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) {
                                          setState(() => _selectedPrinter = v);
                                          _saveSettings();
                                          setDialogState(() {});
                                        },
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
                          onPressed:
                              _isLoadingPrinters ? null : refreshPrinters,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Yopish'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    context.read<LabelingBloc>().add(const LabelingRefreshRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LabelingBloc, LabelingState>(
      // Only rebuild the Scaffold/grid when the items list itself changes.
      // printingItems changes are handled per-card via BlocSelector in
      // _LabelingCardWrapper — rebuilding the entire grid for them is wasteful.
      buildWhen: (previous, current) {
        if (previous is LabelingLoaded && current is LabelingLoaded) {
          return !identical(previous.items, current.items);
        }
        return previous.runtimeType != current.runtimeType;
      },
      listener: (context, state) {
        if (state is LabelingLoaded) {
          final previousCount = _lastItemCount;
          _lastItemCount = state.items.length;

          // If all items are now printed (list became empty), auto-refresh
          if (previousCount > 0 && state.items.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Barcha mahsulotlar yorliqlandi! Sahifa yangilanmoqda...'),
                backgroundColor: AppColors.success,
                duration: Duration(seconds: 2),
              ),
            );

            // Auto-refresh after a short delay to check for new items
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                context
                    .read<LabelingBloc>()
                    .add(const LabelingRefreshRequested());
              }
            });
          }
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
            actions: [
              IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedSettings01,
                  strokeWidth: 2,
                ),
                tooltip: 'Sozlamalar',
                onPressed: _showSettingsDialog,
              ),
              IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedClock01,
                  strokeWidth: 2,
                ),
                tooltip: 'Chop etish tarixi',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PrintHistoryPage(
                        historyService: _historyService,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const HugeIcon(
                  icon: HugeIcons.strokeRoundedReload,
                  strokeWidth: 2,
                ),
                tooltip: 'Yangilash',
                onPressed: _refresh,
              ),
            ],
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
                    Expanded(child: _buildContent(state)),
                  ],
                ),
              ),

              // ── Off-screen labels rendered on-demand (only while printing) ─
              ..._renderingItems.values.map((item) {
                final key = _keyFor(item.id);
                final barcodeValue = item.variantBarcode?.isNotEmpty == true
                    ? item.variantBarcode!
                    : 'TGC-${item.variantId.toString().padLeft(8, '0')}';
                // NOT switched to item.unitSerial here on purpose: _onPrint()
                // below renders and sends to the printer optimistically,
                // BEFORE the print-label API response (which carries the new
                // serial) resolves — the network call and the physical print
                // are decoupled today. Wiring the serial into the printed QR
                // needs that sequencing reworked first (await the response,
                // then render), which is exactly why
                // instructions/phase-3/02-production-units-serials.md stages
                // "print the serial" as a later, separate client release
                // (§7 step 4) rather than bundling it with the backend
                // change. Backend still mints/tracks a real unit serial per
                // print in the background regardless — see
                // ProductionBatchService::incrementProducedQuantity().
                final qrData = buildLabelQr(batchId: item.batchId, itemId: item.id);

                return Positioned(
                  // Positioned far off-screen so the label never flashes
                  // over the UI, but is still painted (Clip.none) so that
                  // RepaintBoundary.toImage() can capture it.
                  left: -100000,
                  top: -100000,
                  child: SizedBox(
                    width: _config.widthPx.toDouble(),
                    height: _config.heightPx.toDouble(),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: key,
                        child: getLabelWidget(
                          style: _labelStyle,
                          productName: item.productName,
                          quality: item.qualityName ?? '',
                          type: item.productTypeName ?? '',
                          color: item.colorName ?? '',
                          sizeLabel: item.sizeLabel,
                          edgeCode: item.edgeCode,
                          barcodeValue: barcodeValue,
                          qrData: qrData,
                        ),
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

  Widget getLabelWidget({
    required _LabelStyle style,
    required String productName,
    required String quality,
    required String type,
    required String color,
    required String sizeLabel,
    required String barcodeValue,
    required String qrData,
    String? edgeCode,
  }) {
    switch (style) {
      case _LabelStyle.asosiy:
        return PrintLabel7050(
          productName: productName,
          quality: quality,
          type: type,
          color: color,
          sizeLabel: sizeLabel,
          edgeCode: edgeCode,
          barcodeValue: barcodeValue,
          qrData: qrData,
        );
      case _LabelStyle.asosiyArab:
        return PrintLabel7050Arab(
          productName: productName,
          quality: quality,
          type: type,
          color: color,
          sizeLabel: sizeLabel,
          edgeCode: edgeCode,
          barcodeValue: barcodeValue,
          qrData: qrData,
        );
    }
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

    // Cached: only recomputed when items reference or filter values change.
    final result = _computeFiltered(items);

    final isDesktop = Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux;

    return Row(
      children: [
        if (isDesktop)
          RepaintBoundary(
            child: MachineFilterSidebar(
              groups: result.machineGroups,
              selectedMachine: _selectedMachine,
              onMachineSelected: (m) => setState(() {
                _selectedMachine = m;
                _cachedItems = const [];
                _currentPage = 0;
              }),
            ),
          ),
        if (isDesktop)
          RepaintBoundary(
            child: ClientFilterSidebar(
              groups: result.clientGroups,
              selectedClient: _selectedClient,
              onClientSelected: (c) => setState(() {
                _selectedClient = c;
                _cachedItems = const [];
                _currentPage = 0;
              }),
            ),
          ),
        if (isDesktop)
          RepaintBoundary(
            child: SizeFilterSidebar(
              groups: result.sizeGroups,
              selectedSize: _selectedSize,
              onSizeSelected: (size) => setState(() {
                _selectedSize = size;
                _cachedItems = const [];
                _currentPage = 0;
              }),
            ),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              // 2 rows per page: always fills the screen with exactly 2 rows
              // of cards regardless of column count.
              const rowsPerPage = 2;

              final crossAxisCount =
                  ((constraints.maxWidth + spacing) / (260 + spacing))
                      .floor()
                      .clamp(1, 3);
              final pageSize = crossAxisCount * rowsPerPage;
              final totalPages =
                  ((result.displayedItems.length + pageSize - 1) ~/ pageSize)
                      .clamp(1, 999999);
              // clamp so the page never goes out of range after items shrink
              final safeCurrentPage =
                  _currentPage.clamp(0, totalPages - 1);
              final pageItems = result.displayedItems
                  .skip(safeCurrentPage * pageSize)
                  .take(pageSize)
                  .toList(growable: false);

              // Compute card height so the grid exactly fills the available
              // vertical space (minus the pagination bar when visible).
              final showPagination = totalPages > 1;
              const paginationBarHeight = 56.0;
              const verticalPadding = 24.0; // top 12 + bottom 12
              final gridAreaHeight = constraints.maxHeight -
                  (showPagination ? paginationBarHeight : 0.0) -
                  verticalPadding;
              // Subtract the GridView's horizontal padding (16 + 16 = 32 px)
              // so the aspect ratio matches the actual rendered cell width.
              const gridHPadding = 32.0;
              final cardWidth =
                  (constraints.maxWidth -
                          gridHPadding -
                          spacing * (crossAxisCount - 1)) /
                      crossAxisCount;
              final rowHeight =
                  (gridAreaHeight - spacing * (rowsPerPage - 1)) /
                      rowsPerPage;
              // Clamp ensures the fixed info section (~170 px) always fits;
              // the image area above it is Expanded and absorbs the rest.
              final childAspectRatio =
                  (cardWidth / rowHeight.clamp(200, double.maxFinite))
                      .clamp(0.3, 2.0);

              return Column(
                children: [
                  Expanded(
                    child: result.displayedItems.isEmpty
                        ? const Center(
                            child: Text(
                              'Tanlangan filtrlar bo\'yicha mahsulot topilmadi.',
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                16, 12, 16, 12),
                            physics:
                                const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: spacing,
                              mainAxisSpacing: spacing,
                              childAspectRatio: childAspectRatio,
                            ),
                            itemCount: pageItems.length,
                            itemBuilder: (context, index) {
                              final item = pageItems[index];
                              return RepaintBoundary(
                                key: ValueKey(item.id),
                                child: _LabelingCardWrapper(
                                  item: item,
                                  isPrintPlatform: _isPrintingPlatform,
                                  onPrint: () => _onPrint(item),
                                ),
                              );
                            },
                          ),
                  ),
                  _PaginationBar(
                    currentPage: safeCurrentPage,
                    totalPages: totalPages,
                    totalItems: result.displayedItems.length,
                    onPrevious: safeCurrentPage > 0
                        ? () => setState(
                            () => _currentPage = safeCurrentPage - 1)
                        : null,
                    onNext: safeCurrentPage < totalPages - 1
                        ? () => setState(
                            () => _currentPage = safeCurrentPage + 1)
                        : null,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Pagination bar ───────────────────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.outlined(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Oldingi sahifa',
            onPressed: onPrevious,
          ),
          const SizedBox(width: 20),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${currentPage + 1} / $totalPages',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '$totalItems ta mahsulot',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(width: 20),
          IconButton.outlined(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Keyingi sahifa',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ── Card wrapper: subscribes only to its own printing state ──────────────────
// Each card uses BlocSelector so when one item starts/stops printing only
// that single card rebuilds — not the entire grid.

class _LabelingCardWrapper extends StatelessWidget {
  const _LabelingCardWrapper({
    required this.item,
    required this.isPrintPlatform,
    required this.onPrint,
  });

  final LabelingItemEntity item;
  final bool isPrintPlatform;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<LabelingBloc, LabelingState, bool>(
      selector: (state) =>
          state is LabelingLoaded && state.printingItems[item.id] == true,
      builder: (context, isPrinting) {
        return _LabelingCard(
          item: item,
          isPrinting: isPrinting,
          isPrintPlatform: isPrintPlatform,
          onPrint: onPrint,
        );
      },
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Image area: fills all space left after the info section ───
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                item.colorImageUrl != null
                    ? AppThumbnail(
                        imageUrl: item.colorImageUrl!,
                      )
                    : const _PlaceholderImage(),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Builder(
                    builder: (_) {
                      final parts = [item.clientName, item.machineName]
                          .whereType<String>()
                          .toList();
                      final label = parts.isNotEmpty
                          ? parts.join(' | ')
                          : (item.batchTitle ?? 'Batch #${item.batchId}');
                      return AppBadge(
                        label: label,
                        color: AppColors.textPrimary,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // ── Info section ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.edgeCode != null ? '${item.productName} [${item.edgeCode}]' : item.productName} | ${item.sizeLabel} | ${item.colorName?.toUpperCase() ?? '—'}',
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
                    value: item.netTarget > 0
                        ? item.producedQuantity / item.netTarget
                        : 0,
                    minHeight: 6,
                    backgroundColor: AppColors.divider,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bajarildi: ${item.producedQuantity} / ${item.netTarget}  •  Qoldi: $remaining',
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

    return Row(
      spacing: 6,
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
  const _PlaceholderImage();

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
