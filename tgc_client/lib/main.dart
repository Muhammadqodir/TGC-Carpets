import 'dart:io';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/di/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isMacOS) {
    await windowManager.ensureInitialized();

    // launch_at_startup setup is only needed on Windows (macOS uses LaunchAgent)
    if (Platform.isWindows) {
      final packageInfo = await PackageInfo.fromPlatform();
      launchAtStartup.setup(
        appName: packageInfo.appName,
        appPath: Platform.resolvedExecutable,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final isLabelTerminal = prefs.getBool('isLabelPrintingTerminal') ?? false;

    final windowOptions = WindowOptions(fullScreen: isLabelTerminal);
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await initDependencies();
  runApp(const App());
}
