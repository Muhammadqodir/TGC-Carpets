import 'dart:io';

import 'package:flutter/material.dart';
import 'package:usb_label_print/usb_label_print.dart';

void main() {
  runApp(const TgcPrinterExampleApp());
}

class TgcPrinterExampleApp extends StatelessWidget {
  const TgcPrinterExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TGC Printer Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const PrinterPage(),
    );
  }
}

class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key});

  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  // -- Services --
  final _discoveryService = PrinterDiscoveryService();
  final _printerService = PrinterService();

  // -- GlobalKey for RepaintBoundary (used to capture label as PNG) --
  final _labelKey = GlobalKey();

  // -- State --
  List<String> _printers = [];
  String? _selectedPrinter;
  String? _generatedPngPath;
  bool _isLoading = false;
  String _statusMessage = '';

  // -- Label config (size + DPI) --
  LabelConfig _labelConfig = LabelConfig.preset58x40;

  // Available presets for the dropdown
  static final _presets = <String, LabelConfig>{
    '58 x 40 mm': LabelConfig.preset58x40,
    '58 x 30 mm': LabelConfig.preset58x30,
    '40 x 30 mm': LabelConfig.preset40x30,
    '80 x 50 mm': LabelConfig.preset80x50,
  };
  String _selectedPreset = '58 x 40 mm';

  // -- Label content --
  final _textController = TextEditingController(text: 'TGC Carpets\nSKU: CP-001\nQuality: Premium');
  final _qrDataController = TextEditingController(text: 'https://tgc-carpets.com/product/CP-001');

  @override
  void initState() {
    super.initState();
    _refreshPrinters();
  }

  @override
  void dispose() {
    _textController.dispose();
    _qrDataController.dispose();
    super.dispose();
  }

  /// Discover available system printers
  Future<void> _refreshPrinters() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Discovering printers...';
    });

    final printers = await _discoveryService.discoverPrinters();

    setState(() {
      _printers = printers;
      _isLoading = false;

      if (printers.isEmpty) {
        _selectedPrinter = null;
        _statusMessage = 'No printers found.';
      } else {
        // Auto-select first printer if none selected
        _selectedPrinter ??= printers.first;
        _statusMessage = 'Found ${printers.length} printer(s).';
      }
    });
  }

  /// Render the label widget to a PNG file
  Future<void> _generatePng() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Generating PNG...';
    });

    final renderer = LabelRenderer(_labelKey);
    // pixelRatio=1.0 so PNG pixels match the config exactly
    final path = await renderer.renderToPng(pixelRatio: 1.0);

    setState(() {
      _generatedPngPath = path;
      _isLoading = false;
      _statusMessage = path != null
          ? 'PNG saved to: $path'
          : 'Failed to generate PNG.';
    });
  }

  /// Print the generated PNG to the selected printer
  Future<void> _printLabel() async {
    if (_generatedPngPath == null) {
      setState(() => _statusMessage = 'Generate a PNG first.');
      return;
    }
    if (_selectedPrinter == null) {
      setState(() => _statusMessage = 'Select a printer first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Printing...';
    });

    final success = await _printerService.printFile(
      filePath: _generatedPngPath!,
      printerName: _selectedPrinter!,
      config: _labelConfig,
    );

    setState(() {
      _isLoading = false;
      _statusMessage = success
          ? 'Print job sent to $_selectedPrinter!'
          : 'Print failed. Check printer and file.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TGC Label Printer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -- Left panel: controls --
            SizedBox(
              width: 360,
              child: _buildControlsPanel(),
            ),
            const SizedBox(width: 32),

            // -- Right panel: label preview + generated image --
            Expanded(
              child: _buildPreviewPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // -- Label text input --
        const Text('Label Text', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _textController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter label text...',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),

        // -- QR data input --
        const Text('QR Code Data', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _qrDataController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter QR code data...',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),

        // -- Label size preset --
        const Text('Label Size', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedPreset,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: _presets.keys
              .map((k) => DropdownMenuItem(value: k, child: Text(k)))
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedPreset = value;
                _labelConfig = _presets[value]!;
                _generatedPngPath = null; // reset PNG when size changes
              });
            }
          },
        ),
        const SizedBox(height: 4),
        Text(
          '${_labelConfig.widthPx} x ${_labelConfig.heightPx} px @ ${_labelConfig.dpi} DPI',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),

        // -- Printer selection --
        const Text('Printer', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey(_printers.length),
                initialValue: _selectedPrinter,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                hint: const Text('Select printer'),
                items: _printers
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedPrinter = value),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _isLoading ? null : _refreshPrinters,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Printers',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // -- Action buttons --
        FilledButton.icon(
          onPressed: _isLoading ? null : _generatePng,
          icon: const Icon(Icons.image),
          label: const Text('Generate PNG'),
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: _isLoading || _generatedPngPath == null || _selectedPrinter == null
              ? null
              : _printLabel,
          icon: const Icon(Icons.print),
          label: const Text('Print'),
        ),
        const SizedBox(height: 24),

        // -- Status message --
        if (_isLoading) const LinearProgressIndicator(),
        if (_statusMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: TextStyle(
              color: _statusMessage.contains('failed') || _statusMessage.contains('No printers')
                  ? Colors.red
                  : Colors.green.shade700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -- Live preview of the label widget --
          Text(
            'Label Preview (${_labelConfig.widthMm.toStringAsFixed(0)} x ${_labelConfig.heightMm.toStringAsFixed(0)} mm)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            // Wrap in RepaintBoundary so we can capture it as PNG
            child: RepaintBoundary(
              key: _labelKey,
              child: LabelWidget(
                text: _textController.text,
                qrData: _qrDataController.text.isEmpty
                    ? 'empty'
                    : _qrDataController.text,
                config: _labelConfig,
                logo: const Icon(Icons.grid_view_rounded, size: 40, color: Colors.teal),
              ),
            ),
          ),

          // -- Show generated PNG preview --
          if (_generatedPngPath != null) ...[
            const SizedBox(height: 32),
            const Text(
              'Generated PNG Preview',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: Image.file(
                File(_generatedPngPath!),
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              _generatedPngPath!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}
