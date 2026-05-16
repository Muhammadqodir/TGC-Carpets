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
import '../bloc/labeling_bloc.dart';
import '../bloc/labeling_event.dart';
import '../bloc/labeling_state.dart';
import 'print_history_page.dart';

// ── Shared preferences keys ─────────────────────────────────────────────────
const _kPrefLabelStyle = 'labeling_label_style';
const _kPrefLabelSize = 'labeling_label_size';
const _kPrefDpi = 'labeling_dpi';
const _kPrefPrinter = 'labeling_printer';

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
                              qrData: 'P1 I1',
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
                final qrData = 'P${item.batchId} I${item.id}';

                return Positioned(
                  left: 0,
                  top: 0,
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
                          sizeLabel: item.sizeLabel + " R",
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
  }) {
    switch (style) {
      case _LabelStyle.asosiy:
        return PrintLabel7050(
          productName: productName,
          quality: quality,
          type: type,
          color: color,
          sizeLabel: sizeLabel,
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
    final printingItems =
        state is LabelingLoaded ? state.printingItems : <int, bool>{};

    // Machine groups reflect the active client + size filters.
    final machineSourceItems = items.where((item) {
      if (_selectedClient != null &&
          (item.clientName ?? '—') != _selectedClient) return false;
      if (_selectedSize != null && item.sizeLabel != _selectedSize) return false;
      return true;
    }).toList();
    final machineGroups = <String, List<LabelingItemEntity>>{};
    for (final item in machineSourceItems) {
      machineGroups.putIfAbsent(item.machineName ?? '—', () => []).add(item);
    }

    // Client groups reflect the active machine + size filters.
    final clientSourceItems = items.where((item) {
      if (_selectedMachine != null &&
          (item.machineName ?? '—') != _selectedMachine) return false;
      if (_selectedSize != null && item.sizeLabel != _selectedSize) return false;
      return true;
    }).toList();
    final clientGroups = <String, List<LabelingItemEntity>>{};
    for (final item in clientSourceItems) {
      clientGroups.putIfAbsent(item.clientName ?? '—', () => []).add(item);
    }

    // Size groups reflect the active machine + client filters.
    final sizeSourceItems = items.where((item) {
      if (_selectedMachine != null &&
          (item.machineName ?? '—') != _selectedMachine) return false;
      if (_selectedClient != null &&
          (item.clientName ?? '—') != _selectedClient) return false;
      return true;
    }).toList();
    final sizeGroups = <String, List<LabelingItemEntity>>{};
    for (final item in sizeSourceItems) {
      sizeGroups.putIfAbsent(item.sizeLabel, () => []).add(item);
    }

    // Filter displayed items by all active filters.
    var displayedItems = items;
    if (_selectedMachine != null) {
      displayedItems = displayedItems
          .where((item) => (item.machineName ?? '—') == _selectedMachine)
          .toList();
    }
    if (_selectedClient != null) {
      displayedItems = displayedItems
          .where((item) => (item.clientName ?? '—') == _selectedClient)
          .toList();
    }
    if (_selectedSize != null) {
      displayedItems = displayedItems
          .where((item) => item.sizeLabel == _selectedSize)
          .toList();
    }

    final isDesktop = Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.linux;

    return Row(
      children: [
        if (isDesktop)
          MachineFilterSidebar(
            groups: machineGroups,
            selectedMachine: _selectedMachine,
            onMachineSelected: (m) => setState(() => _selectedMachine = m),
          ),
        if (isDesktop)
          ClientFilterSidebar(
            groups: clientGroups,
            selectedClient: _selectedClient,
            onClientSelected: (c) => setState(() => _selectedClient = c),
          ),
        if (isDesktop)
          SizeFilterSidebar(
            groups: sizeGroups,
            selectedSize: _selectedSize,
            onSizeSelected: (size) => setState(() => _selectedSize = size),
          ),
        Expanded(
          child: SizedBox(
            height: double.infinity,
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 12.0;
                    final crossAxisCount =
                        ((constraints.maxWidth + spacing) / (260 + spacing))
                            .floor()
                            .clamp(1, 3);
                    final cardWidth =
                        (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
                            crossAxisCount;

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: displayedItems.map((item) {
                        return SizedBox(
                          key: ValueKey(item.id),
                          width: cardWidth,
                          child: RepaintBoundary(
                            child: _LabelingCard(
                              item: item,
                              isPrinting: printingItems[item.id] == true,
                              isPrintPlatform: _isPrintingPlatform,
                              onPrint: () => _onPrint(item),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
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
                    ? AppThumbnail(
                        imageUrl: item.colorImageUrl!,
                      )
                    : _PlaceholderImage(),
              ),
              Positioned(
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
