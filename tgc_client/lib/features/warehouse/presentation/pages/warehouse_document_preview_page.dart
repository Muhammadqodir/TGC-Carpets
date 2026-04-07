import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/datasources/warehouse_remote_datasource.dart';
import '../../data/services/warehouse_pdf_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../domain/entities/warehouse_document_entity.dart';
import '../bloc/warehouse_form_bloc.dart';
import '../bloc/warehouse_form_event.dart';
import '../bloc/warehouse_form_state.dart';
import 'print_labels_args.dart';
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
              if (row.productColorId != null)
                'product_color_id': row.productColorId,
              if (row.productSizeId != null)
                'product_size_id': row.productSizeId,
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

  /// Merges the API-returned [document] items with the preview args rows to
  /// produce [PrintLabelItem] list. Preview rows supply quality/color/type
  /// display labels which are not stored on the document item entity.
  PrintLabelsArgs _buildPrintLabelsArgs(WarehouseDocumentEntity document) {
    // Mutable copy so we can consume rows one-by-one to avoid double-matching
    // when a product appears twice with different colours but the same size.
    final previewRows = List<WarehouseItemPreviewRow>.from(widget.args.items);

    final labelItems = document.items.map((docItem) {
      final matchIdx = previewRows.indexWhere(
        (r) =>
            r.productId == docItem.productId &&
            r.productSizeId == docItem.productSizeId,
      );

      WarehouseItemPreviewRow? preview;
      if (matchIdx >= 0) {
        preview = previewRows[matchIdx];
        previewRows.removeAt(matchIdx);
      }

      final fallbackBarcode =
          'TGC-VAR-${(docItem.variantId ?? docItem.id).toString().padLeft(8, '0')}';

      return PrintLabelItem(
        productName: docItem.productName,
        quality: preview?.quality,
        type: preview?.type,
        color: preview?.color,
        sizeLabel: docItem.productSizeLabel ?? preview?.sizeLabel,
        barcodeValue: docItem.barcodeValue?.isNotEmpty == true
            ? docItem.barcodeValue!
            : fallbackBarcode,
        qrData: '${document.id}/${docItem.variantId ?? docItem.id}',
        quantity: docItem.quantity,
      );
    }).toList();

    return PrintLabelsArgs(
      documentId: document.id,
      items: labelItems,
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
          final printArgs = _buildPrintLabelsArgs(state.document);
          context.pushReplacement(
            AppRoutes.printLabels,
            extra: printArgs,
          );
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
        body: SizedBox(
          height: double.infinity,
          child: Stack(
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
                  child: Expanded(
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
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ],
                            )
                          : const Text('Tasdiqlash va saqlash'),
                    ),
                  ),
                ),
              ),
              // ── Processing overlay ─────────────────────────────────────
              if (_isProcessing)
                const ModalBarrier(
                    dismissible: false, color: Colors.transparent),
            ],
          ),
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
    final totalQty = args.items.fold(0, (sum, r) => sum + r.quantity);
    final sqmValues =
        args.items.map((r) => r.squareMeters).whereType<double>().toList();
    final totalSqm =
        sqmValues.isEmpty ? null : sqmValues.fold<double>(0.0, (a, b) => a + b);

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
                        alignment: Alignment.centerRight,
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
                    alignment: Alignment.centerLeft,
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 12),

                LayoutBuilder(
                  builder: (context, constraints) {
                    bool isDesktop =
                        constraints.maxWidth >= AppConstants.desktopBreakpoint;

                    return Column(
                      children: [
                        _TableHeader(
                          textTheme: textTheme,
                          isDesktop: isDesktop,
                        ),
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
                            isDesktop: isDesktop,
                          );
                        }),
                      ],
                    );
                  },
                ),

                const Divider(height: 1),
                const SizedBox(height: 16),

                // ── Totals ────────────────────────────────────────────
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Jami: $totalQty dona',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      if (totalSqm != null)
                        Text(
                          'Jami: ${fmtSqM(totalSqm)}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
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
              style: textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary),
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
  final Alignment alignment;
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: alignment == Alignment.centerLeft
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: [
        if (alignment == Alignment.centerLeft)
          HugeIcon(
            icon: icon,
            size: 16,
            color: AppColors.textSecondary,
            strokeWidth: 1.5,
          ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: alignment == Alignment.centerLeft
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (alignment == Alignment.centerRight)
          HugeIcon(
            icon: icon,
            size: 16,
            color: AppColors.textSecondary,
            strokeWidth: 1.5,
          ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  final TextTheme textTheme;
  final bool isDesktop;

  const _TableHeader({required this.textTheme, this.isDesktop = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: _hCell('#', textTheme),
          ),
          Expanded(
            flex: 3,
            child: _hCell('Mahsulot', textTheme),
          ),
          if (isDesktop) ...[
            Expanded(
              flex: 2,
              child: _hCell('Sifat', textTheme),
            ),
            Expanded(
              flex: 2,
              child: _hCell('Turi', textTheme),
            ),
            Expanded(
              flex: 2,
              child: _hCell('Rangi', textTheme),
            ),
          ],
          SizedBox(
            width: 70,
            child: _hCell("O'lcham", textTheme),
          ),
          SizedBox(
            width: 60,
            child: _hCell('Miqdor', textTheme, align: TextAlign.end),
          ),
          SizedBox(
            width: 80,
            child: _hCell('Miqdor (м²)', textTheme, align: TextAlign.end),
          ),
        ],
      ),
    );
  }

  Widget _hCell(String text, TextTheme t,
          {TextAlign align = TextAlign.start}) =>
      Text(text,
          textAlign: align,
          style: t.labelSmall?.copyWith(
              color: AppColors.textSecondary, fontWeight: FontWeight.w600));
}

class _TableRow extends StatelessWidget {
  final int index;
  final WarehouseItemPreviewRow row;
  final bool isEven;
  final TextTheme textTheme;
  final bool isDesktop;

  const _TableRow({
    required this.index,
    required this.row,
    required this.isEven,
    required this.textTheme,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isEven ? Colors.transparent : const Color(0xFFF9FAFB),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text('${index + 1}.',
                style: textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ),
          !isDesktop
              ? Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.productName,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${row.quality ?? '—'} | ${row.type ?? '—'} | ${row.color ?? '—'}',
                        style: textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : Expanded(
                  flex: 3,
                  child: Text(
                    row.productName,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
          if (isDesktop) ...[
            Expanded(
              flex: 2,
              child: Text(row.quality ?? '—',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(
              flex: 2,
              child: Text(row.type ?? '—',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
            Expanded(
              flex: 2,
              child: Text(row.color ?? '—',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
          ],
          SizedBox(
            width: 70,
            child: Text(
              row.sizeLabel ?? '—',
              style: row.sizeLabel != null
                  ? textTheme.bodySmall?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w600)
                  : textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${row.quantity}',
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              row.squareMeters != null ? fmtSqM(row.squareMeters!) : '—',
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
