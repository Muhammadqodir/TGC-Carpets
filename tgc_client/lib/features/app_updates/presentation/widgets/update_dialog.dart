import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/app_release_entity.dart';
import '../bloc/app_update_bloc.dart';
import '../bloc/app_update_event.dart';
import '../bloc/app_update_state.dart';

/// Shows a dialog informing the user about an available update.
/// Pass [release] (from [AppUpdateAvailable] state) and the [bloc].
///
/// Handles required vs optional updates:
///   - Required  → WillPopScope prevents dismissal; no "Keyinroq" button.
///   - Optional  → User may dismiss.
Future<void> showUpdateDialog(
  BuildContext context, {
  required AppReleaseEntity release,
  required AppUpdateBloc bloc,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: !release.isRequired,
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: _UpdateDialog(release: release),
    ),
  );
}

class _UpdateDialog extends StatelessWidget {
  final AppReleaseEntity release;

  const _UpdateDialog({required this.release});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !release.isRequired,
      child: BlocConsumer<AppUpdateBloc, AppUpdateState>(
        listener: (context, state) {
          // Close the dialog once the system installer is launched
          if (state is AppUpdateInstalling) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('O\'rnatuvchi ishga tushirildi. Iltimos, ko\'rsatmalarga amal qiling.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
        },
        builder: (context, state) {
          final isInstalling = state is AppUpdateDownloading || state is AppUpdateInstalling;

          return AlertDialog(
            title: Text('Yangi versiya: ${release.version}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (release.isRequired)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Bu yangilanish majburiy.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (release.changelog != null && release.changelog!.isNotEmpty) ...[
                  const Text(
                    'O\'zgarishlar:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    release.changelog!,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                ],

                if (state is AppUpdateDownloading) ...[
                  LinearProgressIndicator(value: state.progress),
                  const SizedBox(height: 6),
                  Text(
                    'Yuklanmoqda… ${(state.progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ] else if (state is AppUpdateInstalling) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 6),
                  const Text('O\'rnatilmoqda…', style: TextStyle(fontSize: 12)),
                ] else if (state is AppUpdateError) ...[
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
            actions: isInstalling
                ? null
                : [
                    if (!release.isRequired)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Keyinroq'),
                      ),
                    FilledButton(
                      onPressed: () {
                        context
                            .read<AppUpdateBloc>()
                            .add(InstallUpdateRequested(release));
                      },
                      child: const Text('Yangilash'),
                    ),
                  ],
          );
        },
      ),
    );
  }
}
