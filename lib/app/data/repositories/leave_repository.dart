import '../models/leave_model.dart';
import '../models/leave_balance_model.dart';
import '../providers/api_provider.dart';
import '../providers/local_database.dart';

class LeaveRepository {
  final ApiProvider apiProvider;
  final LocalDatabase localDatabase;

  LeaveRepository({required this.apiProvider, required this.localDatabase});

  /// Fetches current leave balance from API (`GET /leave/balance`) and caches locally.
  Future<LeaveBalanceModel> fetchLeaveBalance({String? employeeId}) async {
    final response = await apiProvider.get('/leave/balance');
    final data = response.data;
    final payload =
        (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>)
        ? data['data'] as Map<String, dynamic>
        : (data is Map<String, dynamic> ? data : <String, dynamic>{});
    final balance = LeaveBalanceModel.fromJson(payload);

    if (employeeId != null && employeeId.isNotEmpty) {
      await saveLeaveBalance(employeeId, balance);
    }

    return balance;
  }

  /// Fetches leave requests list from API (`GET /leave/requests`) and caches locally.
  Future<List<LeaveModel>> fetchLeaveRequests({String? employeeId}) async {
    final response = await apiProvider.get('/leave/requests');
    final data = response.data;
    List<dynamic> list;
    if (data is Map<String, dynamic> && data['data'] is List) {
      list = data['data'] as List<dynamic>;
    } else if (data is List) {
      list = data;
    } else {
      list = [];
    }

    final requests = list
        .map((e) => LeaveModel.fromJson(e as Map<String, dynamic>))
        .toList();

    if (requests.isNotEmpty) {
      await saveLeaveRequests(requests);
    }

    return requests;
  }

  /// Submits a new leave request to the API (`POST /leave/requests`) and caches it locally.
  Future<LeaveModel> postLeaveRequest({
    required String employeeId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    final response = await apiProvider.post(
      '/leave/requests',
      data: {
        'employeeId': employeeId,
        'leaveType': leaveType,
        'startDate': startDate,
        'endDate': endDate,
        'reason': reason,
      },
    );

    final data = response.data;
    final payload =
        (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>)
        ? data['data'] as Map<String, dynamic>
        : (data is Map<String, dynamic> ? data : <String, dynamic>{});

    final createdLeave = LeaveModel.fromJson(payload);
    await saveLeaveRequests([createdLeave]);
    return createdLeave;
  }

  // ==========================================
  // LOCAL SQLITE CACHE METHODS
  // ==========================================

  /// Saves leave balance to local SQLite cache.
  Future<void> saveLeaveBalance(
    String employeeId,
    LeaveBalanceModel balance,
  ) async {
    await localDatabase.upsertLeaveBalance(employeeId, balance);
  }

  /// Retrieves cached leave balance from local SQLite cache.
  Future<LeaveBalanceModel?> getCachedLeaveBalance(String employeeId) async {
    return await localDatabase.getLeaveBalance(employeeId);
  }

  /// Saves leave requests to local SQLite cache.
  Future<void> saveLeaveRequests(List<LeaveModel> requests) async {
    await localDatabase.upsertLeaveRequests(requests);
  }

  /// Retrieves cached leave requests from local SQLite cache.
  Future<List<LeaveModel>> getCachedLeaveRequests(String employeeId) async {
    return await localDatabase.getLeaveRequests(employeeId);
  }

  /// Retrieves active (Pending or Approved) leave requests to validate date overlaps.
  Future<List<LeaveModel>> getActiveLeaveRequests(String employeeId) async {
    return await localDatabase.getActiveLeaveRequests(employeeId);
  }
}
