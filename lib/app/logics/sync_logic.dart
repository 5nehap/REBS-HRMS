import '../core/services/connectivity_service.dart';
import '../data/repositories/attendance_repository.dart';

class SyncLogic {
  final AttendanceRepository attendanceRepository;
  final ConnectivityService connectivityService;

  SyncLogic({
    required this.attendanceRepository,
    required this.connectivityService,
  });

  /// Check whether synchronization should run based on network connectivity
  bool shouldTriggerSync() {
    return connectivityService.isOnline.value;
  }
}
