import 'package:flutter/material.dart';

class XprinterTest extends StatelessWidget {
  const XprinterTest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Text('Xprinter test'),
            ElevatedButton(
              onPressed: () {
                
              },
              child: const Text('Test print'),
            )
          ],
        ),
      ),
    );
  }
}
