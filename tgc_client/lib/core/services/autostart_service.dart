import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

/// Handles registering / unregistering the app as a login item.
/// - macOS: writes / removes a LaunchAgent plist in ~/Library/LaunchAgents/
/// - Windows: delegates to the launch_at_startup package (registry-based)
class AutostartService {
  static const _bundleId = 'com.example.tgcClient';

  static String get _launchAgentPath {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Library/LaunchAgents/$_bundleId.plist';
  }

  static Future<void> enable() async {
    try {
      if (Platform.isMacOS) {
        await _writeLaunchAgentPlist();
      } else if (Platform.isWindows) {
        await launchAtStartup.enable();
      }
    } catch (_) {
      // Silently ignore — autostart is non-critical
    }
  }

  static Future<void> disable() async {
    try {
      if (Platform.isMacOS) {
        await _removeLaunchAgentPlist();
      } else if (Platform.isWindows) {
        await launchAtStartup.disable();
      }
    } catch (_) {
      // Silently ignore — autostart is non-critical
    }
  }

  static Future<void> _writeLaunchAgentPlist() async {
    final executablePath = Platform.resolvedExecutable;
    final plist = '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$_bundleId</string>
    <key>ProgramArguments</key>
    <array>
        <string>$executablePath</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>''';

    final file = File(_launchAgentPath);
    await file.writeAsString(plist);
    await Process.run('launchctl', ['load', _launchAgentPath]);
  }

  static Future<void> _removeLaunchAgentPlist() async {
    final file = File(_launchAgentPath);
    if (await file.exists()) {
      await Process.run('launchctl', ['unload', _launchAgentPath]);
      await file.delete();
    }
  }
}
