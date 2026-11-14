import 'package:flutter/material.dart';

import '../../features/scanner/presentation/pages/scan_info_page.dart';
import '../../features/shipments/presentation/widgets/shipment_scan_flow.dart'
    show cleanScannedLabel;
import '../di/injection.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';
import 'hardware_scanner.dart';

/// Starts the PDA scanner for the whole app: a carpet label scanned on any
/// page that does not take the scan itself opens [ScanInfoPage].
///
/// Pages that do take it (the shipment form) claim the scanner and get the
/// scan instead; see [HardwareScanner.claim].
Future<void> startScanAnywhere() {
  return HardwareScanner.instance.start((raw) {
    final code = cleanScannedLabel(raw);
    if (code == null || ScanInfoPage.isOpen) return;

    final router = sl<AppRouter>().router;
    final path = router.routerDelegate.currentConfiguration.uri.path;
    // Not logged in yet: there is nothing a scan could be shown with.
    if (path == AppRoutes.splash || path == AppRoutes.login) return;

    router.routerDelegate.navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => ScanInfoPage(code: code),
    ));
  });
}
