import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class AttendanceCard extends StatelessWidget {
  final VoidCallback? onCheckInPressed;
  final VoidCallback? onCheckOutPressed;

  const AttendanceCard({
    super.key,
    this.onCheckInPressed,
    this.onCheckOutPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today\'s Attendance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Icon(Icons.access_time_rounded, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Status: Not Marked',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onCheckInPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                    child: const Text('Check In'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCheckOutPressed,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: const Text('Check Out'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
