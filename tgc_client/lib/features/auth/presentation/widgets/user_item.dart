import 'package:flutter/material.dart';
import 'package:tgc_client/core/ui/widgets/typograpthy.dart';
import 'package:tgc_client/features/auth/domain/entities/user_entity.dart';

class UserItem extends StatelessWidget {
  const UserItem({
    super.key,
    required this.isSelected,
    required this.user,
    required this.onTap,
  });

  final bool isSelected;
  final UserEntity user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BodyText(
                    text: user.name,
                    fontWeight: FontWeight.bold,
                  ),
                  BodyText(
                    text: user.email,
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
