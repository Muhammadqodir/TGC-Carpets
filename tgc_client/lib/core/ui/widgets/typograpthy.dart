import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';

class BodyText extends StatelessWidget {
  const BodyText({
    super.key,
    required this.text,
    this.fontWeight = FontWeight.w500,
    this.textAlign = TextAlign.start,
  });
  final String text;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(fontWeight: fontWeight),
      textAlign: textAlign,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class SubBodyText extends StatelessWidget {
  const SubBodyText({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(color: AppColors.textSecondary),
      overflow: TextOverflow.ellipsis,
    );
  }
}
