import 'package:flutter/material.dart';
import 'package:tgc_client/core/theme/app_colors.dart';

class ConfirmDialog {
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Tasdiqlash',
    String cancelText = 'Bekor qilish',
  }) async {
    bool? result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelText),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(ctx).pop(true);
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
