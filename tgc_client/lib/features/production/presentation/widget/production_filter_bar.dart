import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/range_date_picker.dart';
import '../../domain/entities/machine_entity.dart';

class ProductionFilterBar extends StatelessWidget {
  final String? selectedStatus;
  final MachineEntity? selectedMachine;
  final DateTimeRange? selectedDateRange;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<MachineEntity?> onMachineChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onRefresh;
  final List<MachineEntity> machines;

  const ProductionFilterBar({
    super.key,
    this.selectedStatus,
    this.selectedMachine,
    this.selectedDateRange,
    required this.onStatusChanged,
    required this.onMachineChanged,
    required this.onDateRangeChanged,
    required this.onRefresh,
    this.machines = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Status filter
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Holat',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Barchasi')),
                DropdownMenuItem(
                    value: 'planned', child: Text('Rejalashtirilgan')),
                DropdownMenuItem(
                    value: 'in_progress',
                    child: Text('Ishlab chiqarilmoqda')),
                DropdownMenuItem(
                    value: 'completed', child: Text('Yakunlangan')),
                DropdownMenuItem(
                    value: 'cancelled', child: Text('Bekor qilingan')),
              ],
              onChanged: onStatusChanged,
            ),
          ),
          const SizedBox(width: 12),
          // Machine filter
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int?>(
              value: selectedMachine?.id,
              decoration: const InputDecoration(
                labelText: 'Mashina',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Barchasi')),
                ...machines.map((m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.name),
                    )),
              ],
              onChanged: (machineId) {
                if (machineId == null) {
                  onMachineChanged(null);
                } else {
                  final machine =
                      machines.firstWhere((m) => m.id == machineId);
                  onMachineChanged(machine);
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          // Date range
          SizedBox(
            width: 240,
            child: RangeDatePicker(
              value: selectedDateRange ?? RangeDatePicker.currentMonth,
              onChanged: (range) => onDateRangeChanged(range),
            ),
          ),
          const Spacer(),
          // Refresh
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: onRefresh,
            tooltip: 'Yangilash',
          ),
        ],
      ),
    );
  }
}
