import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tgc_client/core/di/injection.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import 'package:tgc_client/features/clients/domain/entities/client_entity.dart';
import 'package:tgc_client/features/clients/presentation/bloc/client_form_bloc.dart';
import 'package:tgc_client/features/clients/presentation/bloc/client_form_state.dart';
import 'package:tgc_client/features/clients/presentation/widget/client_form_body.dart';

/// Shows the add/edit client form inside a desktop dialog.
/// On success calls [onClientAdded] then closes.
class AddClientModal {
  const AddClientModal._();

  static void show(
    BuildContext context, {
    required VoidCallback onClientAdded,
    ClientEntity? client,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => BlocProvider(
        create: (_) => sl<ClientFormBloc>(),
        child: _AddClientDialogContent(
          onClientAdded: onClientAdded,
          onClose: () => Navigator.of(dialogCtx).pop(),
          client: client,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AddClientDialogContent extends StatefulWidget {
  const _AddClientDialogContent({
    required this.onClientAdded,
    required this.onClose,
    this.client,
  });

  final VoidCallback onClientAdded;
  final VoidCallback onClose;
  final ClientEntity? client;

  @override
  State<_AddClientDialogContent> createState() =>
      _AddClientDialogContentState();
}

class _AddClientDialogContentState extends State<_AddClientDialogContent> {
  final _bodyKey = GlobalKey<ClientFormBodyState>();

  void _submit() => _bodyKey.currentState?.submitToBloc();

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClientFormBloc, ClientFormState>(
      listener: (context, state) {
        if (state is ClientFormSuccess) {
          widget.onClientAdded();
          widget.onClose();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.client != null
                    ? '"${state.client.shopName}" yangilandi.'
                    : '"${state.client.shopName}" mijozi yaratildi.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state is ClientFormFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width: 520,
          height: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title bar
              _DialogTitleBar(
                title: widget.client != null
                    ? 'Mijozni tahrirlash'
                    : 'Mijoz qo\'shish',
                onClose: widget.onClose,
              ),
              const Divider(height: 1, color: AppColors.divider),

              // Shared form body
              Expanded(
                child: ClientFormBody(
                  key: _bodyKey,
                  contentPadding: const EdgeInsets.all(20),
                  initialClient: widget.client,
                ),
              ),

              // Action buttons
              const Divider(height: 1, color: AppColors.divider),
              _DialogActions(
                onCancel: widget.onClose,
                onSave: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DialogTitleBar extends StatelessWidget {
  const _DialogTitleBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Yopish',
          ),
        ],
      ),
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({required this.onCancel, required this.onSave});

  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: onCancel,
            child: const Text('Bekor qilish'),
          ),
          const SizedBox(width: 12),
          BlocBuilder<ClientFormBloc, ClientFormState>(
            builder: (context, state) {
              final submitting = state is ClientFormSubmitting;
              return FilledButton(
                onPressed: submitting ? null : onSave,
                child: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Saqlash'),
              );
            },
          ),
        ],
      ),
    );
  }
}
