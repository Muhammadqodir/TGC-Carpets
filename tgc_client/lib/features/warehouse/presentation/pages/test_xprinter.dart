import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:tgc_client/core/theme/app_colors.dart';

class TestXprinterPage extends StatefulWidget {
  const TestXprinterPage({super.key});

  @override
  State<TestXprinterPage> createState() => _TestXprinterPageState();
}

class _TestXprinterPageState extends State<TestXprinterPage> {
  final _printer = FlutterThermalPrinter.instance;

  List<Printer> _printers = [];
  Printer? _selectedPrinter;
  StreamSubscription<List<Printer>>? _scanSubscription;
  bool _isScanning = false;
  bool _isPrinting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _printer.stopScan();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Scan
  // ---------------------------------------------------------------------------

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _printers = [];
      _statusMessage = null;
    });

    // Cancel old subscription and stop any ongoing scan first
    _scanSubscription?.cancel();
    await _printer.stopScan();

    // IMPORTANT: subscribe to the broadcast stream BEFORE calling getPrinters().
    // The initial USB results are emitted synchronously during getPrinters() —
    // subscribing too late causes those events to be silently dropped.
    _scanSubscription =
        _printer.devicesStream.listen((List<Printer> devices) {
      if (!mounted) return;
      final visible = devices
          .where((p) => p.name != null && p.name!.isNotEmpty)
          .toList();
      setState(() {
        _printers = visible;
        // Auto-select the first connected printer if none is selected yet
        if (_selectedPrinter == null) {
          final alreadyConnected = visible.where((p) => p.isConnected ?? false);
          if (alreadyConnected.isNotEmpty) {
            _selectedPrinter = alreadyConnected.first;
          }
        }
      });
    });

    // Try USB only
    try {
      await _printer.getPrinters(
        connectionTypes: [ConnectionType.USB],
      );
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Scan error: $e');
    }

    // Auto-stop after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        _printer.stopScan();
        setState(() => _isScanning = false);
      }
    });
  }

  void _stopScan() {
    _printer.stopScan();
    setState(() => _isScanning = false);
  }

  // ---------------------------------------------------------------------------
  // Select / Connect
  // ---------------------------------------------------------------------------

  Future<void> _onPrinterTap(Printer device) async {
    final isSelected = _selectedPrinter?.address == device.address;

    if (device.isConnected ?? false) {
      // Already connected — just toggle selection for printing
      setState(() {
        _selectedPrinter = isSelected ? null : device;
        _statusMessage = isSelected
            ? null
            : 'Selected: ${device.name}';
      });
      return;
    }

    // Not yet connected — connect first, then select
    setState(() => _statusMessage = 'Connecting to ${device.name}…');
    final connected = await _printer.connect(device);
    if (mounted) {
      setState(() {
        _statusMessage = connected
            ? 'Selected: ${device.name}'
            : 'Failed to connect to ${device.name}';
        if (connected) _selectedPrinter = device;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Print Hello World
  // ---------------------------------------------------------------------------

  Future<void> _printHelloWorld() async {
    final target = _selectedPrinter;
    if (target == null) {
      setState(() => _statusMessage = 'Please select a printer first.');
      return;
    }

    setState(() {
      _isPrinting = true;
      _statusMessage = null;
    });

    try {
      await _printer.printWidget(
        context,
        printer: target,
        paperSize: PaperSize.mm58,
        cutAfterPrinted: true,
        widget: _buildLabelWidget(),
      );

      if (mounted) {
        setState(() => _statusMessage = 'Printed successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = 'Print error: $e');
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  /// The widget that gets rendered and sent to the 58 mm label printer.
  Widget _buildLabelWidget() {
    return SizedBox(
      // 58 mm at 203 dpi ≈ 384 px — standard for mm58 thermal printers
      width: 384,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Hello World',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'TGC Carpets — Label 58x40',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Test Xprinter',
          style: TextStyle(fontFamily: 'Onest', fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Scan again',
              onPressed: _startScan,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status banner
          if (_statusMessage != null)
            _StatusBanner(message: _statusMessage!),

          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                Text(
                  'Available Printers',
                  style: TextStyle(
                    fontFamily: 'Onest',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                if (_isScanning)
                  GestureDetector(
                    onTap: _stopScan,
                    child: Text(
                      'Scanning…  stop',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryLight,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Printer list
          Expanded(
            child: _printers.isEmpty
                ? _EmptyPrinterList(isScanning: _isScanning)
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _printers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final device = _printers[index];
                      final isConnected = device.isConnected ?? false;
                      final isSelected =
                          _selectedPrinter?.address == device.address;

                      return _PrinterTile(
                        device: device,
                        isConnected: isConnected,
                        isSelected: isSelected,
                        onTap: () => _onPrinterTap(device),
                      );
                    },
                  ),
          ),

          // Label preview + print button
          _LabelPreview(
            selectedPrinter: _selectedPrinter,
            isPrinting: _isPrinting,
            onPrint: _printHelloWorld,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final isError = message.toLowerCase().contains('error') ||
        message.toLowerCase().contains('failed');
    return Container(
      color: isError ? AppColors.error : AppColors.success,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Onest',
          fontSize: 13,
        ),
      ),
    );
  }
}

class _PrinterTile extends StatelessWidget {
  const _PrinterTile({
    required this.device,
    required this.isConnected,
    required this.isSelected,
    required this.onTap,
  });

  final Printer device;
  final bool isConnected;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.06)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : isConnected
                      ? AppColors.success
                      : AppColors.divider,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.print_rounded,
                color: isConnected ? AppColors.success : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name ?? 'Unknown Printer',
                      style: const TextStyle(
                        fontFamily: 'Onest',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (device.address != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        device.address!,
                        style: const TextStyle(
                          fontFamily: 'Onest',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _ConnectionBadge(isConnected: isConnected, isSelected: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.isConnected, required this.isSelected});
  final bool isConnected;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final label = isSelected
        ? 'Selected'
        : isConnected
            ? 'Tap to select'
            : 'Tap to connect';
    final bgColor = isSelected
        ? AppColors.primary.withValues(alpha: 0.12)
        : isConnected
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.divider;
    final textColor = isSelected
        ? AppColors.primary
        : isConnected
            ? AppColors.success
            : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Onest',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _LabelPreview extends StatelessWidget {
  const _LabelPreview({
    required this.selectedPrinter,
    required this.isPrinting,
    required this.onPrint,
  });

  final Printer? selectedPrinter;
  final bool isPrinting;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 12),

          // 58x40 mm label preview
          Center(
            child: Container(
              width: 220,
              height: 152, // 58:40 approx ratio scaled up
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.divider, width: 1.5),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Hello World',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'TGC Carpets — Label 58x40',
                    style: TextStyle(
                      fontFamily: 'Onest',
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '58 × 40 mm',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Print button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedPrinter != null
                    ? AppColors.primary
                    : AppColors.divider,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed:
                  selectedPrinter != null && !isPrinting ? onPrint : null,
              icon: isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.print_rounded),
              label: Text(
                isPrinting
                    ? 'Printing…'
                    : selectedPrinter == null
                        ? 'Connect a printer to print'
                        : 'Print Hello World',
                style: const TextStyle(
                  fontFamily: 'Onest',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPrinterList extends StatelessWidget {
  const _EmptyPrinterList({required this.isScanning});
  final bool isScanning;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.print_disabled_rounded,
            size: 48,
            color: AppColors.divider,
          ),
          const SizedBox(height: 12),
          Text(
            isScanning ? 'Scanning for printers…' : 'No printers found',
            style: const TextStyle(
              fontFamily: 'Onest',
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          if (!isScanning) ...[
            const SizedBox(height: 8),
            Text(
              'Make sure your printer is on and in range.',
              style: TextStyle(
                fontFamily: 'Onest',
                fontSize: 12,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
