import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/hardware/hardware_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../labeling/domain/carpet_number.dart';
import '../../../labeling/domain/label_qr_format.dart';
import '../../../labeling/domain/product_barcode.dart';
import '../../../shipments/presentation/widgets/shipment_scan_flow.dart'
    show cleanScannedLabel;
import '../bloc/scanner_bloc.dart';
import '../bloc/scanner_event.dart';
import '../bloc/scanner_state.dart';
import 'scanner_page.dart' show ScanResultView;

/// What a carpet is, opened by the PDA's trigger from any page that has no
/// use for the scan itself (the shipment page keeps its own).
///
/// Holds the scanner while it is showing, so the next trigger press shows
/// the next carpet in place instead of stacking pages.
class ScanInfoPage extends StatelessWidget {
  final String code;
  const ScanInfoPage({super.key, required this.code});

  /// True while one is on screen, so the app-wide handler never opens a
  /// second on top of it.
  static bool isOpen = false;

  /// Whether [code] is something this page can look up: the 21 carpet
  /// number or the square code on a production label.
  static bool canShow(String code) =>
      isCarpetNumber(code) || isProductionLabelQr(code);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ScannerBloc>(),
      child: _ScanInfoView(initialCode: code),
    );
  }
}

class _ScanInfoView extends StatefulWidget {
  final String initialCode;
  const _ScanInfoView({required this.initialCode});

  @override
  State<_ScanInfoView> createState() => _ScanInfoViewState();
}

class _ScanInfoViewState extends State<_ScanInfoView> {
  VoidCallback? _releaseScanner;
  String? _refusal;
  late String _code;

  @override
  void initState() {
    super.initState();
    ScanInfoPage.isOpen = true;
    _releaseScanner = HardwareScanner.instance.claim(_onScan);
    _show(widget.initialCode);
  }

  @override
  void dispose() {
    _releaseScanner?.call();
    ScanInfoPage.isOpen = false;
    super.dispose();
  }

  void _onScan(String raw) {
    final code = cleanScannedLabel(raw);
    if (code == null || !mounted) return;
    // A dialog or another page above this one: not meant for us.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _show(code);
  }

  void _show(String code) {
    setState(() {
      _code = code;
      _refusal = _refusalFor(code);
    });
    if (_refusal != null) {
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      return;
    }
    context.read<ScannerBloc>().add(ScannerCodeScanned(code));
  }

  static String? _refusalFor(String code) {
    if (ScanInfoPage.canShow(code)) return null;
    if (code.startsWith(productBarcodePrefix) && isEan13(code)) {
      return 'Bu mahsulot shtrix-kodi. Gilam haqida ma\'lumot uchun '
          'yorliqdagi 21 bilan boshlanadigan kodni yoki kvadrat kodni '
          'skanerlang.';
    }
    return 'Bu kod TGC yorlig\'iga o\'xshamaydi.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8ECEF),
      appBar: AppBar(
        title: const Text('Mahsulot ma\'lumoti'),
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            strokeWidth: 2,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: _refusal != null
          ? _Message(
              icon: Icons.info_rounded,
              color: AppColors.warning,
              title: 'Boshqa kodni skanerlang',
              text: '$_refusal\nKod: $_code',
            )
          : BlocConsumer<ScannerBloc, ScannerState>(
              listener: (context, state) {
                if (state is ScannerError) {
                  HapticFeedback.heavyImpact();
                  SystemSound.play(SystemSoundType.alert);
                }
              },
              builder: (context, state) => switch (state) {
                ScannerLoaded(:final item) => ScanResultView(
                    item: item,
                    // On a PDA "scan again" fires the imager.
                    onReset: HardwareScanner.instance.softTrigger,
                  ),
                ScannerError(:final message) => _Message(
                    icon: Icons.error_rounded,
                    color: AppColors.error,
                    title: 'Topilmadi',
                    text: '$message\nKod: $_code',
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;

  const _Message({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: HardwareScanner.instance.softTrigger,
              icon: const Icon(Icons.barcode_reader),
              label: const Text('Qayta skanerlash'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
