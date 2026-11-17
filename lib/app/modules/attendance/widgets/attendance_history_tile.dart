import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../../../data/models/attendance_model.dart';
import 'sync_status_chip.dart';

class AttendanceHistoryTile extends StatelessWidget {
  final AttendanceModel attendance;
  final String syncStatus; // 'PENDING', 'SYNCED', 'REJECTED'

  const AttendanceHistoryTile({
    super.key,
    required this.attendance,
    this.syncStatus = AppConstants.syncSynced,
  });

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--';
    final parsed = DateHelper.parseDate(isoString);
    if (parsed == null) return isoString;
    return DateHelper.formatTime(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withAlpha(25),
              child: const Icon(
                Icons.event_available_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: [
                      Text(
                        attendance.workingDate,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SyncStatusChip(status: syncStatus),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'In: ${_formatTime(attendance.checkInTimestamp)} | Out: ${_formatTime(attendance.checkOutTimestamp)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: attendance.attendanceStatus == 'Present'
                    ? AppColors.success
                    : AppColors.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                attendance.attendanceStatus,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
