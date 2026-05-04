import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';

class SettingsBool extends StatelessWidget {
  const SettingsBool({
    super.key,
    this.title = 'Bo\'lim nomi',
    this.description = 'Bo\'lim haqida qisqacha ma\'lumot',
    this.value = true,
    this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final void Function(bool)? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged?.call(!value),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BodyText(
                    text: title,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 4),
                  SubBodyText(
                    text: description,
                  )
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
