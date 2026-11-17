import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_routes.dart';
import '../../attendance/widgets/attendance_history_tile.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/employee_card.dart';
import '../widgets/attendance_card.dart';
import '../widgets/leave_balance_card.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  Future<void> _navigateToAttendance() async {
    // Navigate to Attendance screen and refresh status and recent history on return
    await Get.toNamed(AppRoutes.attendance);
    await controller.refreshTodayAttendanceStatus();
  }

  Future<void> _navigateToLeave() async {
    await Get.toNamed(AppRoutes.leave);
    await controller.loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('REBS HRMS Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Dashboard',
            onPressed: controller.loadDashboardData,
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value &&
            controller.currentEmployee.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.errorMessage.value.isNotEmpty &&
            controller.currentEmployee.value == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: controller.loadDashboardData,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Offline Mode Banner
                if (controller.isOffline.value)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    color: AppColors.warning.withAlpha(35),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 18,
                          color: AppColors.warning,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Offline Mode — Showing local cached data',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. Employee Profile Card
                      EmployeeCard(employee: controller.currentEmployee.value),
                      const SizedBox(height: 8),

                      // 3. Today's Attendance & Metrics Card
                      AttendanceCard(
                        status: controller.todayAttendanceStatus.value,
                        checkInTime: controller.todayCheckInTime.value,
                        checkOutTime: controller.todayCheckOutTime.value,
                        workingDuration: controller.workingDuration.value,
                        onCheckInPressed: _navigateToAttendance,
                        onCheckOutPressed: _navigateToAttendance,
                      ),
                      const SizedBox(height: 8),

                      // 4. Leave Balances Card
                      LeaveBalanceCard(balance: controller.leaveBalance.value),
                      const SizedBox(height: 12),

                      // 5. Quick Navigation Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _navigateToAttendance,
                              icon: const Icon(Icons.history_rounded, size: 18),
                              label: const Text('Attendance'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _navigateToLeave,
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                              ),
                              label: const Text('Leaves'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 6. Recent Attendance (Latest 5) Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recent Attendance (Latest 5)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: _navigateToAttendance,
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 7. Recent Attendance List or Empty State
                      if (controller.latestAttendance.isEmpty)
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 24.0,
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.event_busy_rounded,
                                    size: 36,
                                    color: AppColors.textMuted,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No recent attendance records found',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: controller.latestAttendance.length,
                          itemBuilder: (context, index) {
                            final item = controller.latestAttendance[index];
                            final syncStatus = controller.getSyncStatusForDate(
                              item.workingDate,
                            );
                            return AttendanceHistoryTile(
                              attendance: item,
                              syncStatus: syncStatus,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
