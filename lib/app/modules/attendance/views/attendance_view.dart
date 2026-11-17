import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/attendance_controller.dart';
import '../widgets/attendance_action_button.dart';
import '../widgets/attendance_history_tile.dart';

class AttendanceView extends GetView<AttendanceController> {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: AttendanceActionButton(
                      label: 'Check In',
                      icon: Icons.login_rounded,
                      color: AppColors.success,
                      onPressed: controller.checkIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AttendanceActionButton(
                      label: 'Check Out',
                      icon: Icons.logout_rounded,
                      color: AppColors.error,
                      onPressed: controller.checkOut,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.loadAttendanceHistory,
                child: ListView.builder(
                  itemCount: controller.history.length,
                  itemBuilder: (context, index) {
                    final item = controller.history[index];
                    return AttendanceHistoryTile(attendance: item);
                  },
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
