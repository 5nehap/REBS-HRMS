import 'package:get/get.dart';
import '../controllers/leave_controller.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../data/repositories/leave_repository.dart';
import '../../../logics/leave_logic.dart';

class LeaveBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LeaveController>(
      () => LeaveController(
        leaveRepository: Get.find<LeaveRepository>(),
        leaveLogic: Get.find<LeaveLogic>(),
        connectivityService: Get.isRegistered<ConnectivityService>()
            ? Get.find<ConnectivityService>()
            : null,
      ),
    );
  }
}
