import 'package:flutter/material.dart';
import 'package:simple_numpad/simple_numpad.dart';
import 'package:tgc_client/core/theme/app_colors.dart';

class OTPPad extends StatefulWidget {
  const OTPPad({
    super.key,
    this.onComplete,
  });

  /// Callback triggered when password length reaches 5
  final void Function(String password)? onComplete;

  @override
  State<OTPPad> createState() => _OTPPadState();
}

class _OTPPadState extends State<OTPPad> {
  String _value = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _value
                  .split('')
                  .map((e) => OTPCell())
                  .toList(growable: false),
            ),
          ),
          SizedBox(
            height: 24,
          ),
          SimpleNumpad(
            buttonWidth: 100,
            buttonHeight: 100,
            gridSpacing: 10,
            buttonBorderRadius: 30,
            useBackspace: true,
            onPressed: (v) {
              print(v);
              setState(() {
                if (v == 'BACKSPACE') {
                  if (_value.isNotEmpty) {
                    _value = _value.substring(0, _value.length - 1);
                  }
                } else {
                  if (_value.length < 5) {
                    _value += v;
                    // Auto-submit when password length reaches 5
                    if (_value.length == 5) {
                      widget.onComplete?.call(_value);
                      // Reset after a short delay
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          setState(() {
                            _value = '';
                          });
                        }
                      });
                    }
                  }
                }
              });
            },
          ),
        ],
      ),
    );
  }
}

class OTPCell extends StatelessWidget {
  const OTPCell({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('●', style: TextStyle(fontSize: 24)),
    );
  }
}
