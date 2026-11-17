import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/attendance_model.dart';

class AttendanceHistoryTile extends StatelessWidget {
  final AttendanceModel attendance;

  const AttendanceHistoryTile({super.key, required this.attendance});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withAlpha(25),
          child: const Icon(
            Icons.event_available_rounded,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          attendance.workingDate,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          'In: ${attendance.checkInTimestamp ?? "--"} | Out: ${attendance.checkOutTimestamp ?? "--"}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        trailing: Chip(
          label: Text(
            attendance.attendanceStatus,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: attendance.attendanceStatus == 'Present'
              ? AppColors.success
              : AppColors.error,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
