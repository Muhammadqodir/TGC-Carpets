import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/app_option_selector.dart';
import '../../domain/entities/raw_material_entity.dart';
import '../../domain/usecases/get_raw_materials_usecase.dart';
import '../bloc/batch_movement_bloc.dart';
import '../bloc/batch_movement_event.dart';
import '../bloc/batch_movement_state.dart';
import '../widgets/batch_movement_row_widget.dart';

/// Page for recording a batch of raw-material stock movements (receive/spend).
class RawMaterialBatchMovementPage extends StatelessWidget {
  const RawMaterialBatchMovementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<BatchMovementBloc>(),
      child: const _BatchMovementView(),
    );
  }
}

class _BatchMovementView extends StatefulWidget {
  const _BatchMovementView();

  @override
  State<_BatchMovementView> createState() => _BatchMovementViewState();
}

class _BatchMovementViewState extends State<_BatchMovementView> {
  final _formKey   = GlobalKey<FormState>();
  final _notesCtrl = TextEditingController();
  DateTime _dateTime = DateTime.now();
  String _movementType = 'received';

  final List<BatchMovementRow> _rows = [];
  List<RawMaterialEntity> _allMaterials = [];
  bool _loadingMaterials = true;

  static const _types = [
    (label: 'Kirim', value: 'received'),
    (label: 'Chiqim', value: 'spent'),
  ];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    final useCase = sl<GetRawMaterialsUseCase>();
    final result = await useCase(perPage: 200);
    result.fold(
      (_) => setState(() => _loadingMaterials = false),
      (paginated) => setState(() {
        _allMaterials = paginated.data;
        _loadingMaterials = false;
      }),
    );
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addRow(RawMaterialEntity material) {
    // Prevent duplicates
    if (_rows.any((r) => r.material.id == material.id)) return;
    setState(() => _rows.add(BatchMovementRow(material: material)));
  }

  void _removeRow(int index) {
    setState(() {
      _rows[index].dispose();
      _rows.removeAt(index);
    });
  }

  Future<void> _pickMaterial() async {
    final available =
        _allMaterials.where((m) => !_rows.any((r) => r.material.id == m.id)).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barcha xom ashyolar qo\'shilgan.')),
      );
      return;
    }

    final picked = await showModalBottomSheet<RawMaterialEntity>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MaterialPickerSheet(materials: available),
    );

    if (picked != null) _addRow(picked);
  }

  void _submit() {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamida bitta xom ashyo qo\'shing.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final items = _rows
        .map((r) => {
              'material_id': r.material.id,
              'quantity': double.parse(r.qtyController.text),
            })
        .toList();

    context.read<BatchMovementBloc>().add(BatchMovementSubmitted(
          dateTime:
              _dateTime.toIso8601String().replaceFirst('T', ' ').substring(0, 19),
          type:  _movementType,
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          items: items,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BatchMovementBloc, BatchMovementState>(
      listener: (context, state) {
        if (state is BatchMovementSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Harakat muvaffaqiyatli saqlandi.'),
            backgroundColor: AppColors.success,
          ));
          context.pop(true);
        } else if (state is BatchMovementError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: AppColors.error,
          ));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _movementType == 'received' ? 'Kirim' : 'Chiqim',
          ),
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_outlined, size: 20),
          ),
        ),
        body: _loadingMaterials
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // ── Movement type ──────────────────────────────────
                          AppOptionSelector<String>(
                            label: 'Harakat turi',
                            options: _types,
                            selected: _movementType,
                            onChanged: (v) =>
                                setState(() => _movementType = v),
                          ),
                          const SizedBox(height: 14),

                          // ── Date-time ──────────────────────────────────────
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _pickDateTimme,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Sana va vaqt',
                                suffixIcon: Icon(Icons.calendar_today_outlined),
                              ),
                              child: Text(
                                '${_dateTime.day.toString().padLeft(2, '0')}.${_dateTime.month.toString().padLeft(2, '0')}.${_dateTime.year}  '
                                '${_dateTime.hour.toString().padLeft(2, '0')}:${_dateTime.minute.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ── Notes ──────────────────────────────────────────
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Izoh (ixtiyoriy)',
                              hintText: 'Ushbu partiya haqida izoh...',
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Material rows ──────────────────────────────────
                          Row(
                            children: [
                              Text(
                                'Xom ashyolar',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const Spacer(),
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Qo\'shish'),
                                onPressed: _pickMaterial,
                              ),
                            ],
                          ),
                          const Divider(height: 8),
                          if (_rows.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text(
                                  'Xom ashyo qo\'shish uchun + tugmasini bosing',
                                  style: TextStyle(
                                      color: AppColors.textSecondary),
                                ),
                              ),
                            )
                          else
                            ...List.generate(_rows.length, (i) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: BatchMovementRowWidget(
                                  row: _rows[i],
                                  onRemove: () => _removeRow(i),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),

                    // ── Submit button ──────────────────────────────────────
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: BlocBuilder<BatchMovementBloc,
                            BatchMovementState>(
                          builder: (context, state) {
                            return SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: state is BatchMovementLoading
                                    ? null
                                    : _submit,
                                child: state is BatchMovementLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Saqlash'),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _pickDateTimme() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (!mounted) return;

    setState(() {
      _dateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? _dateTime.hour,
        time?.minute ?? _dateTime.minute,
      );
    });
  }
}

// ── Material picker bottom sheet ────────────────────────────────────────────

class _MaterialPickerSheet extends StatefulWidget {
  final List<RawMaterialEntity> materials;

  const _MaterialPickerSheet({required this.materials});

  @override
  State<_MaterialPickerSheet> createState() => _MaterialPickerSheetState();
}

class _MaterialPickerSheetState extends State<_MaterialPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<RawMaterialEntity> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.materials;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final lower = q.toLowerCase();
    setState(() {
      _filtered = widget.materials
          .where((m) =>
              m.name.toLowerCase().contains(lower) ||
              m.type.toLowerCase().contains(lower))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Xom ashyo qidirish...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: controller,
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final m = _filtered[index];
                return ListTile(
                  title: Text(m.name),
                  subtitle: Text('${m.type} · ${_unitLabel(m.unit)}'),
                  onTap: () => Navigator.of(context).pop(m),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _unitLabel(String unit) => switch (unit) {
        'sqm'   => 'm²',
        'kg'    => 'kg',
        'piece' => 'dona',
        _       => unit,
      };
}
