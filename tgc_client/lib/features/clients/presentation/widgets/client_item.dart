import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:tgc_client/core/theme/app_colors.dart';
import '../../domain/entities/client_entity.dart';

class ClientItem extends StatelessWidget {
  final ClientEntity client;

  const ClientItem({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedStore01,
                color: AppColors.primary,
                strokeWidth: 1.5,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.shopName,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    client.contactName ?? '—',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedCall,
                        size: 13,
                        color: AppColors.textSecondary,
                        strokeWidth: 1.5,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          client.phone ?? '—',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RegionBadge(region: client.region),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegionBadge extends StatelessWidget {
  final String region;

  const _RegionBadge({required this.region});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        region,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
