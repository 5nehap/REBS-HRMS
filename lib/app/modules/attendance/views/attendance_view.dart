import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_helper.dart';
import '../controllers/attendance_controller.dart';
import '../widgets/attendance_action_button.dart';
import '../widgets/attendance_history_tile.dart';
import '../widgets/sync_status_chip.dart';

class AttendanceView extends GetView<AttendanceController> {
  const AttendanceView({super.key});

  String _formatDisplayTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--';
    final parsed = DateHelper.parseDate(isoString);
    if (parsed == null) return isoString;
    return DateHelper.formatTime(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final today = controller.todayAttendance.value;
        final hasCheckedIn = today?.checkInTimestamp != null;
        final hasCheckedOut = today?.checkOutTimestamp != null;
        final isCheckingIn =
            controller.isActionLoading.value &&
            controller.actionTypeLoading.value == AppConstants.eventCheckIn;
        final isCheckingOut =
            controller.isActionLoading.value &&
            controller.actionTypeLoading.value == AppConstants.eventCheckOut;

        final todayDateStr = DateHelper.formatDate(DateTime.now());
        final todaySyncStatus = controller.getSyncStatusForDate(todayDateStr);

        final pendingCount = controller.pendingEvents.length;
        final isSyncing = controller.isSyncing.value;

        return Column(
          children: [
            // 1. Status & Action Card
            Card(
              margin: const EdgeInsets.all(16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Today\'s Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (hasCheckedIn || hasCheckedOut)
                          SyncStatusChip(status: todaySyncStatus),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTimeBox(
                            label: 'Check-In',
                            time: _formatDisplayTime(today?.checkInTimestamp),
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimeBox(
                            label: 'Check-Out',
                            time: _formatDisplayTime(today?.checkOutTimestamp),
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AttendanceActionButton(
                            label: hasCheckedIn ? 'Checked In' : 'Check In',
                            icon: Icons.login_rounded,
                            color: AppColors.success,
                            isLoading: isCheckingIn,
                            onPressed:
                                (hasCheckedIn ||
                                    controller.isActionLoading.value)
                                ? null
                                : controller.checkIn,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AttendanceActionButton(
                            label: hasCheckedOut ? 'Checked Out' : 'Check Out',
                            icon: Icons.logout_rounded,
                            color: AppColors.error,
                            isLoading: isCheckingOut,
                            onPressed:
                                (!hasCheckedIn ||
                                    hasCheckedOut ||
                                    controller.isActionLoading.value)
                                ? null
                                : controller.checkOut,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // 2. Sync Now Control Bar (Above Attendance History)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      pendingCount > 0
                          ? Icons.cloud_queue_rounded
                          : Icons.cloud_done_rounded,
                      color: pendingCount > 0
                          ? AppColors.warning
                          : AppColors.success,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pendingCount > 0
                                ? '$pendingCount pending event${pendingCount > 1 ? "s" : ""}'
                                : 'All events synchronized',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: pendingCount > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            pendingCount > 0
                                ? 'Tap to upload offline records'
                                : 'Local storage matches server',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: (pendingCount > 0 && !isSyncing)
                          ? () => controller.syncNow(isAutomatic: false)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        disabledForegroundColor: AppColors.textMuted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        elevation: 0,
                      ),
                      icon: isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync_rounded, size: 16),
                      label: Text(isSyncing ? 'Syncing...' : 'Sync Now'),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Attendance History Header
            const Padding(
              padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Attendance History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            // 4. Attendance History List
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.loadAttendanceHistory,
                child: controller.history.isEmpty
                    ? const Center(
                        child: Text(
                          'No attendance history found.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: controller.history.length,
                        itemBuilder: (context, index) {
                          final item = controller.history[index];
                          final itemSyncStatus = controller
                              .getSyncStatusForDate(item.workingDate);
                          return AttendanceHistoryTile(
                            attendance: item,
                            syncStatus: itemSyncStatus,
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildTimeBox({
    required String label,
    required String time,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
