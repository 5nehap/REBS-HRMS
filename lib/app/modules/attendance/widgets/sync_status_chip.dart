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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: chipColor, width: 1),
      ),
      child: Text(
        labelText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: chipColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}
