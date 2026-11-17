import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/leave_model.dart';

class LeaveRequestCard extends StatelessWidget {
  final LeaveModel leave;

  const LeaveRequestCard({super.key, required this.leave});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (leave.status.toUpperCase()) {
      case 'APPROVED':
        statusColor = AppColors.success;
        break;
      case 'REJECTED':
        statusColor = AppColors.error;
        break;
      case 'PENDING':
      default:
        statusColor = AppColors.warning;
        break;
    }

    final days = leave.requestedDays;
    final daysText = '$days ${days == 1 ? 'day' : 'days'}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Header: Leave Type and Status Chip
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        leave.leaveType.toUpperCase() == 'SICK'
                            ? Icons.medical_services_outlined
                            : Icons.beach_access_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${leave.leaveType} Leave',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withAlpha(120)),
                  ),
                  child: Text(
                    leave.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 2. Date Range and Duration
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.date_range_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${leave.startDate} to ${leave.endDate}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    daysText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 3. Reason
            Text(
              leave.reason,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
