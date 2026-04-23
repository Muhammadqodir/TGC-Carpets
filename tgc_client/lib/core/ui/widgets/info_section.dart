import 'package:flutter/material.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';

class InfoSection extends StatelessWidget {
  const InfoSection({super.key, required this.items});
  final List<InfoSectionItemData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= AppConstants.desktopBreakpoint;
      if (isDesktop) {
        return Wrap(
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: 24,
          runSpacing: 8,
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BodyText(
                          text: item.label,
                        ),
                        BodyText(
                          text: item.value,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ))
              .toList(),
        );
      }
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: BodyText(
                      text: item.label,
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: BodyText(
                      text: item.value,
                      fontWeight: FontWeight.bold,
                    ),
                  ))
              .toList(),
        )
      ]);
    });
  }
}

class InfoSectionItemData {
  const InfoSectionItemData({
    required this.label,
    required this.value,
  });
  final String label;
  final String value;
}
