import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AttendanceCard extends StatelessWidget {
  final String status;
  final String checkInTime;
  final String checkOutTime;
  final String workingDuration;
  final VoidCallback? onCheckInPressed;
  final VoidCallback? onCheckOutPressed;

  const AttendanceCard({
    super.key,
    this.status = 'Not Checked In',
    this.checkInTime = '--',
    this.checkOutTime = '--',
    this.workingDuration = '00h 00m',
    this.onCheckInPressed,
    this.onCheckOutPressed,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    if (status == 'Checked In') {
      statusColor = AppColors.success;
    } else if (status == 'Checked Out') {
      statusColor = AppColors.info;
    } else {
      statusColor = AppColors.textSecondary;
    }

    final isCheckedIn = status == 'Checked In';
    final isCheckedOut = status == 'Checked Out';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Attendance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withAlpha(80)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      label: 'Check In',
                      value: checkInTime,
                      icon: Icons.login_rounded,
                      iconColor: AppColors.success,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'Check Out',
                      value: checkOutTime,
                      icon: Icons.logout_rounded,
                      iconColor: AppColors.error,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 36,
                    color: AppColors.border,
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'Duration',
                      value: workingDuration,
                      icon: Icons.timelapse_rounded,
                      iconColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isCheckedIn || isCheckedOut
                        ? null
                        : onCheckInPressed,
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: Text(isCheckedIn ? 'Checked In' : 'Check In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: !isCheckedIn || isCheckedOut
                        ? null
                        : onCheckOutPressed,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(isCheckedOut ? 'Checked Out' : 'Check Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      disabledForegroundColor: AppColors.textMuted,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
