import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/leave_repository.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<DashboardController>(
      () => DashboardController(
        employeeRepository: Get.find<EmployeeRepository>(),
        attendanceRepository: Get.find<AttendanceRepository>(),
        leaveRepository: Get.find<LeaveRepository>(),
      ),
    );
  }
}
