import '../models/employee_model.dart';
import '../providers/api_provider.dart';
import '../providers/local_database.dart';

class EmployeeRepository {
  final ApiProvider apiProvider;
  final LocalDatabase localDatabase;

  EmployeeRepository({required this.apiProvider, required this.localDatabase});

  /// Fetches employee profile from API (`/employee/me`) and updates local cache.
  Future<EmployeeModel> fetchCurrentEmployee() async {
    final response = await apiProvider.get('/employee/me');
    final data = response.data as Map<String, dynamic>;
    final payload = (data['data'] is Map<String, dynamic>)
        ? data['data'] as Map<String, dynamic>
        : data;
    final employee = EmployeeModel.fromJson(payload);

    // Cache to SQLite
    await saveEmployee(employee);
    return employee;
  }

  /// Retrieves cached employee profile by ID from SQLite without internet.
  Future<EmployeeModel?> getEmployeeProfile(String employeeId) async {
    return await localDatabase.getEmployee(employeeId);
  }

  /// Upserts employee details into SQLite cache.
  Future<void> saveEmployee(EmployeeModel employee) async {
    await localDatabase.upsertEmployee(employee);
  }

  /// Updates cached employee profile.
  Future<void> updateCachedEmployee(EmployeeModel employee) async {
    await localDatabase.upsertEmployee(employee);
  }
}
