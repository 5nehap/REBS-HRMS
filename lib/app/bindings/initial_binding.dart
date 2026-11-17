import 'package:get/get.dart';
import '../core/services/location_service.dart';
import '../core/services/connectivity_service.dart';
import '../data/providers/api_provider.dart';
import '../data/providers/local_database.dart';
import '../data/repositories/employee_repository.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/leave_repository.dart';
import '../logics/attendance_logic.dart';
import '../logics/leave_logic.dart';
import '../logics/sync_logic.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // 1. Core Providers
    final apiProvider = ApiProvider();
    final localDatabase = LocalDatabase();
    Get.put<ApiProvider>(apiProvider, permanent: true);
    Get.put<LocalDatabase>(localDatabase, permanent: true);

    // 2. Core Device Services
    final locationService = LocationService();
    final connectivityService = ConnectivityService();
    Get.put<LocationService>(locationService, permanent: true);
    Get.put<ConnectivityService>(connectivityService, permanent: true);

    // 3. Repositories
    final employeeRepo = EmployeeRepository(
      apiProvider: apiProvider,
      localDatabase: localDatabase,
    );
    final attendanceRepo = AttendanceRepository(
      apiProvider: apiProvider,
      localDatabase: localDatabase,
    );
    final leaveRepo = LeaveRepository(
      apiProvider: apiProvider,
      localDatabase: localDatabase,
    );
    Get.put<EmployeeRepository>(employeeRepo, permanent: true);
    Get.put<AttendanceRepository>(attendanceRepo, permanent: true);
    Get.put<LeaveRepository>(leaveRepo, permanent: true);

    // 4. Business Logics
    Get.put<AttendanceLogic>(
      AttendanceLogic(locationService: locationService),
      permanent: true,
    );
    Get.put<LeaveLogic>(LeaveLogic(), permanent: true);
    Get.put<SyncLogic>(
      SyncLogic(
        attendanceRepository: attendanceRepo,
        connectivityService: connectivityService,
      ),
      permanent: true,
    );
  }
}
