import 'package:get/get.dart';
import '../controllers/attendance_controller.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../logics/attendance_logic.dart';

class AttendanceBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AttendanceController>(
      () => AttendanceController(
        attendanceRepository: Get.find<AttendanceRepository>(),
        attendanceLogic: Get.find<AttendanceLogic>(),
      ),
    );
  }
}
