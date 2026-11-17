import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/employee_card.dart';
import '../widgets/attendance_card.dart';
import '../widgets/leave_balance_card.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('REBS HRMS Dashboard')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.loadDashboardData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EmployeeCard(employee: controller.currentEmployee.value),
                AttendanceCard(
                  onCheckInPressed: () => Get.toNamed(AppRoutes.attendance),
                  onCheckOutPressed: () => Get.toNamed(AppRoutes.attendance),
                ),
                LeaveBalanceCard(balance: controller.leaveBalance.value),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Get.toNamed(AppRoutes.attendance),
                          icon: const Icon(Icons.history_rounded),
                          label: const Text('Attendance'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Get.toNamed(AppRoutes.leave),
                          icon: const Icon(Icons.calendar_today_rounded),
                          label: const Text('Leaves'),
                        ),
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
