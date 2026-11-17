import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';

class SyncStatusChip extends StatelessWidget {
  final String status;

  const SyncStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color chipColor;
    String labelText;

    switch (status) {
      case AppConstants.syncSynced:
        chipColor = AppColors.success;
        labelText = 'Synced';
        break;
      case AppConstants.syncRejected:
        chipColor = AppColors.error;
        labelText = 'Rejected';
        break;
      case AppConstants.syncPending:
      default:
        chipColor = AppColors.warning;
        labelText = 'Pending Sync';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor),
      ),
      child: Text(
        labelText,
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
