import 'package:get/get.dart';
import '../../../data/models/leave_model.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../../logics/leave_logic.dart';

class LeaveController extends GetxController {
  final LeaveRepository leaveRepository;
  final LeaveLogic leaveLogic;

  LeaveController({required this.leaveRepository, required this.leaveLogic});

  final RxBool isLoading = false.obs;
  final RxList<LeaveModel> leaves = <LeaveModel>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadLeaves();
  }

  Future<void> loadLeaves() async {
    isLoading.value = true;
    try {
      // Future architecture hook: fetch leave history from repository
      leaves.assignAll([
        LeaveModel(
          id: 'LV-101',
          employeeId: 'EMP-001',
          leaveType: 'Casual',
          startDate: '2026-11-20',
          endDate: '2026-11-21',
          reason: 'Family event attendance',
          status: 'Pending',
        ),
      ]);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> submitLeave() async {
    // Architectural placeholder for leave submission
  }
}
