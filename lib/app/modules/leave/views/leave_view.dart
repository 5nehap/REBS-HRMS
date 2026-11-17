import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../routes/app_routes.dart';
import '../controllers/leave_controller.dart';
import '../widgets/leave_request_card.dart';

class LeaveView extends GetView<LeaveController> {
  const LeaveView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Management')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: controller.loadLeaves,
          child: controller.leaves.isEmpty
              ? const Center(child: Text('No leave applications found'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: controller.leaves.length,
                  itemBuilder: (context, index) {
                    final item = controller.leaves[index];
                    return LeaveRequestCard(leave: item);
                  },
                ),
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.applyLeave),
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
      ),
    );
  }
}
