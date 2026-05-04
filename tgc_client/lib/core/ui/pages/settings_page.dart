import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tgc_client/core/ui/widgets/settigs_bool.dart';

class CoreSettingsPage extends StatefulWidget {
  const CoreSettingsPage({super.key});

  @override
  State<CoreSettingsPage> createState() => _CoreSettingsPageState();
}

class _CoreSettingsPageState extends State<CoreSettingsPage> {
  bool _isLabelPrintingTerminal = false;

  @override
  void initState() {
    super.initState();
    _loadSettings().then((value) {
      setState(() {
        _isLabelPrintingTerminal = value;
      });
    });
  }

  Future<bool> _loadSettings() async {
    return (await SharedPreferences.getInstance())
            .getBool('isLabelPrintingTerminal') ??
        false;
  }

  Future<void> _saveSettings(bool value) async {
    await (await SharedPreferences.getInstance())
        .setBool('isLabelPrintingTerminal', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tizim sozlamalari'),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(
          children: [
            SettingsBool(
              title: 'Yorliq bosib chiqarish terminali',
              description:
                  'Yorliq bosib chiqarish terminalini yoqish yoki o\'chirish.',
              value: _isLabelPrintingTerminal,
              onChanged: (val) {
                setState(() {
                  _isLabelPrintingTerminal = val;
                });
                _saveSettings(val);
              },
            )
          ],
        ),
      ),
    );
  }
}
