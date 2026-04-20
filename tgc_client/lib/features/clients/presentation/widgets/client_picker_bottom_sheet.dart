import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/widgets/search_picker_bottom_sheet.dart';
import '../../data/datasources/client_remote_datasource.dart';
import '../../domain/entities/client_entity.dart';

/// Searchable client picker bottom sheet.
/// Returns the selected [ClientEntity] or null if dismissed.
class ClientPickerBottomSheet {
  ClientPickerBottomSheet._();

  static Future<ClientEntity?> show(BuildContext context) {
    return SearchPickerBottomSheet.show<ClientEntity>(
      context,
      title: 'Mijoz tanlash',
      searchHint: 'Do\'kon nomi yoki telefon...',
      onSearch: (query) async {
        final datasource = sl<ClientRemoteDataSource>();
        final result = await datasource.getClients(
          search: query.isEmpty ? null : query,
          perPage: 30,
        );
        return result.data;
      },
      itemBuilder: (context, client) => _ClientPickerTile(client: client),
      emptyText: 'Mijoz topilmadi.',
      errorText: 'Mijozlarni yuklashda xatolik.',
    );
  }
}

class _ClientPickerTile extends StatelessWidget {
  final ClientEntity client;

  const _ClientPickerTile({required this.client});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.shopName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${client.contactName ?? '—'} · ${client.phone ?? '—'}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              client.region,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
