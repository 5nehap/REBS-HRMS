import 'package:get/get.dart';
import '../../../data/models/employee_model.dart';
import '../../../data/models/leave_balance_model.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/leave_repository.dart';

class DashboardController extends GetxController {
  final EmployeeRepository employeeRepository;
  final AttendanceRepository attendanceRepository;
  final LeaveRepository leaveRepository;

  DashboardController({
    required this.employeeRepository,
    required this.attendanceRepository,
    required this.leaveRepository,
  });

  final RxBool isLoading = false.obs;
  final Rx<EmployeeModel?> currentEmployee = Rx<EmployeeModel?>(null);
  final Rx<LeaveBalanceModel?> leaveBalance = Rx<LeaveBalanceModel?>(null);

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
  }

  Future<void> loadDashboardData() async {
    isLoading.value = true;
    try {
      // Future architecture hook: fetch employee profile & balances
      currentEmployee.value = EmployeeModel(
        id: 'EMP-001',
        name: 'Alex Johnson',
        department: 'Engineering',
        officeLatitude: 28.6139,
        officeLongitude: 77.2090,
        companyTimezone: 'Asia/Kolkata',
      );
      leaveBalance.value = LeaveBalanceModel(
        casualLeave: 8,
        sickLeave: 5,
        totalAvailableLeave: 13,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
