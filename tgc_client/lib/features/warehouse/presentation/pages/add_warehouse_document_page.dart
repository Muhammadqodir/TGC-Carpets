import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../data/services/warehouse_document_draft_service.dart';
import '../widgets/warehouse_document_form_controller.dart';
import 'desktop/add_warehouse_document_desktop_page.dart';
import 'mobile/add_warehouse_document_mobile_page.dart';

/// Adaptive entry point for the "add warehouse document" flow.
///
/// Responsibilities:
///   • Owns the [WarehouseDocumentFormController] so state survives
///     mobile ↔ desktop layout switches on resize.
///   • Loads the username once and stores it in the controller.
///   • Auto-saves a draft via [WarehouseDocumentDraftService] after
///     every controller change.
///   • Restores any existing draft on startup.
///   • Clears the draft only when the page is popped with `result == true`
///     (successful submission).  Every other exit (back button, swipe) keeps
///     the draft so the user can resume.
class AddWarehouseDocumentPage extends StatefulWidget {
  const AddWarehouseDocumentPage({super.key});

  @override
  State<AddWarehouseDocumentPage> createState() =>
      _AddWarehouseDocumentPageState();
}

class _AddWarehouseDocumentPageState extends State<AddWarehouseDocumentPage> {
  late final WarehouseDocumentFormController _ctrl;
  late final WarehouseDocumentDraftService _draft;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WarehouseDocumentFormController();
    _ctrl.addListener(_onControllerChanged);
    _init();
  }

  Future<void> _init() async {
    // Read username synchronously from the already-authenticated AuthBloc state
    final authState = sl<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _ctrl.username = authState.user.name;
    }

    // Restore draft from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    _draft = WarehouseDocumentDraftService(prefs);
    await _draft.restore(_ctrl);
    // Controller auto-initializes with an empty row

    if (mounted) setState(() => _ready = true);
  }

  void _onControllerChanged() {
    // Auto-save on every change (fire-and-forget; SharedPreferences is fast)
    if (_ready) _draft.save(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onControllerChanged);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope<bool?>(
      // Always allow the pop; we just react to the result.
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) return;
        if (result == true) {
          // Successful submit → wipe draft
          _draft.clear();
        }
        // Any other exit → draft is already auto-saved; nothing extra needed.
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppConstants.desktopBreakpoint) {
            return AddWarehouseDocumentDesktopPage(controller: _ctrl);
          }
          return AddWarehouseDocumentMobilePage(controller: _ctrl);
        },
      ),
    );
  }
}

