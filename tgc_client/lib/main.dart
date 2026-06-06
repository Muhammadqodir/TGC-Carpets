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

    // Show the window immediately so the process is always visible even if
    // SharedPreferences (AppData) is temporarily locked/corrupted on Windows.
    await windowManager.waitUntilReadyToShow(const WindowOptions(), () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // Apply fullscreen for label terminal mode after the window is visible.
    // Guard with a timeout so a corrupted SharedPreferences file can't block
    // startup — in that case we simply continue in windowed mode.
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 5));
      final isLabelTerminal =
          prefs.getBool('isLabelPrintingTerminal') ?? false;
      if (isLabelTerminal) {
        await windowManager.setFullScreen(true);
      }
    } catch (_) {
      // AppData unavailable — continue without fullscreen.
    }
  }

  await initDependencies();
  runApp(const App());
}
