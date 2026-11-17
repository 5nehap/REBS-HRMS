import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/leave_controller.dart';
import '../widgets/leave_form.dart';

class ApplyLeaveView extends GetView<LeaveController> {
  const ApplyLeaveView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: SingleChildScrollView(
        child: LeaveForm(
          onSubmit: () {
            controller.submitLeave();
            Get.back();
          },
        ),
      ),
    );
  }
}
