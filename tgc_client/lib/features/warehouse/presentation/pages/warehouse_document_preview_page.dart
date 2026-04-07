import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/warehouse_remote_datasource.dart';
import '../../data/services/warehouse_pdf_service.dart';
import '../bloc/warehouse_form_bloc.dart';
import '../bloc/warehouse_form_event.dart';
import '../bloc/warehouse_form_state.dart';
import 'warehouse_document_preview_args.dart';

class WarehouseDocumentPreviewPage extends StatelessWidget {
  final WarehouseDocumentPreviewArgs args;

  const WarehouseDocumentPreviewPage({super.key, required this.args});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<WarehouseFormBloc>(),
      child: _PreviewView(args: args),
    );
  }
}

class _PreviewView extends StatefulWidget {
  final WarehouseDocumentPreviewArgs args;

  const _PreviewView({required this.args});

  @override
  State<_PreviewView> createState() => _PreviewViewState();
}

class _PreviewViewState extends State<_PreviewView> {
  bool _isProcessing = false;
  String _processingLabel = 'Saqlanmoqda...';

  String get _formattedDate {
    final d = widget.args.documentDate;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String get _formattedDateTime {
    final now = DateTime.now();
    final d = widget.args.documentDate;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}   '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _submit() {
    final dateStr =
        '${widget.args.documentDate.year}-${widget.args.documentDate.month.toString().padLeft(2, '0')}-${widget.args.documentDate.day.toString().padLeft(2, '0')}';

    final items = widget.args.items
        .map((row) => {
              'product_id': row.productId,
              if (row.productSizeId != null) 'product_size_id': row.productSizeId,
              'quantity': row.quantity,
              if (row.itemNotes != null && row.itemNotes!.isNotEmpty)
                'notes': row.itemNotes,
            })
        .toList();

    context.read<WarehouseFormBloc>().add(
          WarehouseFormSubmitted(
            type: widget.args.type,
            documentDate: dateStr,
            items: items,
            notes: widget.args.notes,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WarehouseFormBloc, WarehouseFormState>(
      listener: (context, state) async {
        if (state is WarehouseFormSubmitting) {
          setState(() {
            _isProcessing = true;
            _processingLabel = 'Saqlanmoqda...';
          });
        } else if (state is WarehouseFormSuccess) {
          setState(() => _processingLabel = 'PDF tayyorlanmoqda...');
          try {
            await WarehousePdfService(sl<WarehouseRemoteDataSource>())
                .generateAndUpload(
              docId: state.document.id,
              username: widget.args.username,
              documentDate: widget.args.documentDate,
              notes: widget.args.notes,
              items: widget.args.items,
            );
          } catch (_) {
            // PDF upload failure is non-fatal; document is already created.
          }
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kirim hujjati muvaffaqiyatli yaratildi!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop(true);
        } else if (state is WarehouseFormFailure) {
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE8ECEF),
        appBar: AppBar(
          title: const Text('Hujjatni ko\'rib chiqish'),
          leading: IconButton(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              strokeWidth: 2,
            ),
            onPressed: _isProcessing ? null : () => context.pop(),
          ),
        ),
        body: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                child: _DocumentCard(
                  args: widget.args,
                  formattedDateTime: _formattedDateTime,
                  formattedDate: _formattedDate,
                ),
              ),
            ),
            // ── Submit button ──────────────────────────────────────────
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: SafeArea(
                top: false,
                child: FilledButton(
                  onPressed: _isProcessing ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _isProcessing
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(_processingLabel,
                                style: const TextStyle(color: Colors.white)),
                          ],
                        )
                      : const Text('Tasdiqlash va saqlash'),
                ),
              ),
            ),
            // ── Processing overlay ─────────────────────────────────────
            if (_isProcessing)
              const ModalBarrier(dismissible: false, color: Colors.transparent),
          ],
        ),
      ),
    );
  }
}

// ── Document card ─────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final WarehouseDocumentPreviewArgs args;
  final String formattedDateTime;
  final String formattedDate;

  const _DocumentCard({
    required this.args,
    required this.formattedDateTime,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Document header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Column(
              children: [
                Text(
                  'TGC CARPETS',
                  style: textTheme.labelMedium?.copyWith(
                    color: Colors.white60,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'OMBORGA KIRIM HUJJATI',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '№ —',
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Meta row ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _MetaItem(
                        icon: HugeIcons.strokeRoundedUser,
                        label: 'Masul xodim',
                        value: args.username,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _MetaItem(
                        icon: HugeIcons.strokeRoundedCalendar01,
                        label: 'Sana va vaqt',
                        value: formattedDateTime,
                      ),
                    ),
                  ],
                ),

                if (args.notes != null && args.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _MetaItem(
                    icon: HugeIcons.strokeRoundedNote,
                    label: 'Izoh',
                    value: args.notes!,
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // ── Table header ──────────────────────────────────────
                _TableHeader(textTheme: textTheme),
                const Divider(height: 1),

                // ── Table rows ────────────────────────────────────────
                ...args.items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final row = entry.value;
                  return _TableRow(
                    index: i,
                    row: row,
                    isEven: i.isEven,
                    textTheme: textTheme,
                  );
                }),

                const Divider(height: 1),
                const SizedBox(height: 16),

                // ── Totals ────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Jami: ${args.items.fold(0, (sum, r) => sum + r.quantity)} dona',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Signature lines ───────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _SignatureLine(
                        label: 'Topshirdi',
                        name: args.username,
                        textTheme: textTheme,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _SignatureLine(
                        label: 'Qabul qildi',
                        name: '',
                        textTheme: textTheme,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Footer ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            decoration: const BoxDecoration(
              color: Color(0xFFF5F6F8),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Text(
              'Hujjat yaratilish sanasi: $formattedDate',
              style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _MetaItem extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String value;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HugeIcon(icon: icon, size: 16, color: AppColors.textSecondary, strokeWidth: 1.5),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final TextTheme textTheme;

  const _TableHeader({required this.textTheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#',
                style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 4,
            child: Text('Mahsulot',
                style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 72,
            child: Text("O'lcham",
                style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 52,
            child: Text('Miqdor',
                textAlign: TextAlign.end,
                style: textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final int index;
  final WarehouseItemPreviewRow row;
  final bool isEven;
  final TextTheme textTheme;

  const _TableRow({
    required this.index,
    required this.row,
    required this.isEven,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? Colors.transparent : const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text('${index + 1}.',
                style:
                    textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.productName,
                    style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500)),
                if (row.productDetails.isNotEmpty)
                  Text(row.productDetails,
                      style: textTheme.labelSmall
                          ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              row.sizeLabel ?? '—',
              style: row.sizeLabel != null
                  ? textTheme.bodyMedium
                      ?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)
                  : textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${row.quantity}',
              textAlign: TextAlign.end,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureLine extends StatelessWidget {
  final String label;
  final String name;
  final TextTheme textTheme;

  const _SignatureLine({
    required this.label,
    required this.name,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(name,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 8),
        const Divider(
          height: 1,
          thickness: 1,
          color: AppColors.textPrimary,
        ),
        const SizedBox(height: 4),
        Text(
          'Imzo',
          style: textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
