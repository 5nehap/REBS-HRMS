import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/database_exception.dart';
import '../models/employee_model.dart';
import '../models/attendance_model.dart';
import '../models/attendance_event_model.dart';
import '../models/leave_balance_model.dart';
import '../models/leave_model.dart';

class LocalDatabase {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDatabase();
    return _database!;
  }

  Future<Database> initDatabase({String? customPath}) async {
    try {
      final String path;
      if (customPath != null) {
        path = customPath;
      } else {
        final databasesPath = await getDatabasesPath();
        path = p.join(databasesPath, AppConfig.databaseName);
      }

      return await openDatabase(
        path,
        version: AppConfig.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to initialize local SQLite database',
        originalError: e,
      );
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Employees table with last_updated_at
    await db.execute('''
      CREATE TABLE ${AppConstants.tableEmployees} (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        department TEXT NOT NULL,
        office_latitude REAL NOT NULL,
        office_longitude REAL NOT NULL,
        company_timezone TEXT NOT NULL,
        last_updated_at TEXT NOT NULL
      )
    ''');

    // 2. Attendance table (daily overview records) with compound unique constraint
    await db.execute('''
      CREATE TABLE ${AppConstants.tableAttendance} (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        working_date TEXT NOT NULL,
        check_in_timestamp TEXT,
        check_out_timestamp TEXT,
        attendance_status TEXT NOT NULL,
        last_updated_at TEXT NOT NULL,
        UNIQUE(employee_id, working_date)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_attendance_emp_date 
      ON ${AppConstants.tableAttendance} (employee_id, working_date)
    ''');

    // 3. Attendance Events table (persistent offline event queue)
    await db.execute('''
      CREATE TABLE ${AppConstants.tableAttendanceEvents} (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        event_type TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        working_date TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        sync_status TEXT NOT NULL,
        sync_error_message TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_attempted_at TEXT
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_attendance_events_sync 
      ON ${AppConstants.tableAttendanceEvents} (employee_id, sync_status, created_at)
    ''');

    // 4. Leaves table with last_updated_at
    await db.execute('''
      CREATE TABLE ${AppConstants.tableLeaves} (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        leave_type TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL,
        last_updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_leaves_emp_dates 
      ON ${AppConstants.tableLeaves} (employee_id, start_date, end_date)
    ''');

    // 5. Leave Balances table with last_updated_at
    await db.execute('''
      CREATE TABLE ${AppConstants.tableLeaveBalances} (
        employee_id TEXT PRIMARY KEY,
        casual_leave INTEGER NOT NULL,
        sick_leave INTEGER NOT NULL,
        total_available_leave INTEGER NOT NULL,
        last_updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration handling when databaseVersion increments
  }

  Future<void> close() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to close database',
        originalError: e,
      );
    }
  }

  // ==========================================
  // EMPLOYEE LOCAL STORAGE METHODS
  // ==========================================

  /// Upserts employee details into local cache.
  Future<void> upsertEmployee(EmployeeModel employee) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      final map = {
        'id': employee.id,
        'name': employee.name,
        'department': employee.department,
        'office_latitude': employee.officeLatitude,
        'office_longitude': employee.officeLongitude,
        'company_timezone': employee.companyTimezone,
        'last_updated_at': now,
      };

      await db.insert(
        AppConstants.tableEmployees,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to save employee to cache',
        originalError: e,
      );
    }
  }

  /// Retrieves cached employee profile by ID.
  Future<EmployeeModel?> getEmployee(String employeeId) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableEmployees,
        where: 'id = ?',
        whereArgs: [employeeId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return EmployeeModel.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to retrieve cached employee',
        originalError: e,
      );
    }
  }

  // ==========================================
  // ATTENDANCE LOCAL STORAGE METHODS
  // ==========================================

  /// Upserts attendance record (maintains unique record per working day).
  Future<void> upsertAttendance(AttendanceModel attendance) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      final map = {
        'id': attendance.id,
        'employee_id': attendance.employeeId,
        'working_date': attendance.workingDate,
        'check_in_timestamp': attendance.checkInTimestamp,
        'check_out_timestamp': attendance.checkOutTimestamp,
        'attendance_status': attendance.attendanceStatus,
        'last_updated_at': now,
      };

      await db.insert(
        AppConstants.tableAttendance,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to save attendance record',
        originalError: e,
      );
    }
  }

  /// Bulk upserts attendance records within a transaction.
  Future<void> upsertAttendanceBatch(List<AttendanceModel> list) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final item in list) {
          batch.insert(
            AppConstants.tableAttendance,
            {
              'id': item.id,
              'employee_id': item.employeeId,
              'working_date': item.workingDate,
              'check_in_timestamp': item.checkInTimestamp,
              'check_out_timestamp': item.checkOutTimestamp,
              'attendance_status': item.attendanceStatus,
              'last_updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to batch save attendance records',
        originalError: e,
      );
    }
  }

  /// Retrieves today's attendance for an employee.
  Future<AttendanceModel?> getTodayAttendance(
    String employeeId,
    String workingDate,
  ) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableAttendance,
        where: 'employee_id = ? AND working_date = ?',
        whereArgs: [employeeId, workingDate],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return AttendanceModel.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to retrieve today\'s attendance',
        originalError: e,
      );
    }
  }

  /// Retrieves attendance history for a selected month (YYYY-MM).
  Future<List<AttendanceModel>> getMonthlyAttendance(
    String employeeId,
    String yearMonth,
  ) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableAttendance,
        where: 'employee_id = ? AND working_date LIKE ?',
        whereArgs: [employeeId, '$yearMonth%'],
        orderBy: 'working_date DESC',
      );

      return maps.map((e) => AttendanceModel.fromJson(e)).toList();
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to retrieve monthly attendance history',
        originalError: e,
      );
    }
  }

  /// Retrieves the latest 5 attendance records for an employee.
  Future<List<AttendanceModel>> getLatestAttendanceRecords(
    String employeeId, {
    int limit = 5,
  }) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableAttendance,
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'working_date DESC',
        limit: limit,
      );

      return maps.map((e) => AttendanceModel.fromJson(e)).toList();
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to retrieve latest attendance records',
        originalError: e,
      );
    }
  }

  // ==========================================
  // PERSISTENT ATTENDANCE EVENT QUEUE METHODS
  // ==========================================

  /// Inserts a pending attendance event with strict validation and transaction.
  /// Enforces:
  /// 1. Stable UUID idempotency (ignores if same event ID already exists without overwriting).
  /// 2. Event ordering: check-in must exist before check-out for the same working day.
  Future<bool> insertPendingAttendanceEvent(AttendanceEventModel event) async {
    try {
      final db = await database;

      return await db.transaction<bool>((txn) async {
        // 1. Check if event ID already exists
        final existingEvent = await txn.query(
          AppConstants.tableAttendanceEvents,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [event.id],
          limit: 1,
        );

        if (existingEvent.isNotEmpty) {
          // Stable event already stored; do not duplicate or overwrite
          return false;
        }

        // 2. Ordering rule: CHECK_OUT requires an existing CHECK_IN for the same working day
        if (event.eventType == AppConstants.eventCheckOut) {
          // Check if there is an existing CHECK_IN event in the queue
          final checkInEvent = await txn.query(
            AppConstants.tableAttendanceEvents,
            columns: ['id'],
            where:
                'employee_id = ? AND working_date = ? AND event_type = ? AND sync_status != ?',
            whereArgs: [
              event.employeeId,
              event.workingDate,
              AppConstants.eventCheckIn,
              AppConstants.syncRejected,
            ],
            limit: 1,
          );

          if (checkInEvent.isEmpty) {
            // Also check attendance table
            final checkInRecord = await txn.query(
              AppConstants.tableAttendance,
              columns: ['id'],
              where:
                  'employee_id = ? AND working_date = ? AND check_in_timestamp IS NOT NULL',
              whereArgs: [event.employeeId, event.workingDate],
              limit: 1,
            );

            if (checkInRecord.isEmpty) {
              throw LocalDatabaseException(
                message:
                    'Invalid event sequence: Check-in must be recorded before check-out for date ${event.workingDate}',
              );
            }
          }
        }

        // 3. Insert event without silently overwriting (abort on conflict)
        await txn.insert(
          AppConstants.tableAttendanceEvents,
          event.toJson(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );

        return true;
      });
    } catch (e) {
      if (e is LocalDatabaseException) rethrow;
      throw LocalDatabaseException(
        message: 'Failed to insert attendance event into persistent queue',
        originalError: e,
      );
    }
  }

  /// Retrieves pending events in chronological order (FIFO) for synchronization.
  Future<List<AttendanceEventModel>> getPendingAttendanceEvents(
    String employeeId,
  ) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableAttendanceEvents,
        where: 'employee_id = ? AND sync_status = ?',
        whereArgs: [employeeId, AppConstants.syncPending],
        orderBy: 'created_at ASC',
      );

      return maps.map((e) => AttendanceEventModel.fromJson(e)).toList();
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to retrieve pending attendance events',
        originalError: e,
      );
    }
  }

  /// Retrieves all recorded events (Pending, Synced, Rejected) for an employee.
  Future<List<AttendanceEventModel>> getAllAttendanceEvents(
    String employeeId,
  ) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableAttendanceEvents,
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'created_at ASC',
      );

      return maps.map((e) => AttendanceEventModel.fromJson(e)).toList();
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to retrieve all attendance events',
        originalError: e,
      );
    }
  }

  /// Marks an attendance event as SYNCED.
  Future<void> markEventSynced(String eventId) async {
    try {
      final db = await database;
      await db.update(
        AppConstants.tableAttendanceEvents,
        {
          'sync_status': AppConstants.syncSynced,
          'sync_error_message': null,
          'last_attempted_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [eventId],
      );
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to mark event as synced',
        originalError: e,
      );
    }
  }

  /// Marks an attendance event as REJECTED with server reason.
  Future<void> markEventRejected(String eventId, String reason) async {
    try {
      final db = await database;
      await db.update(
        AppConstants.tableAttendanceEvents,
        {
          'sync_status': AppConstants.syncRejected,
          'sync_error_message': reason,
          'last_attempted_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [eventId],
      );
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to mark event as rejected',
        originalError: e,
      );
    }
  }

  /// Increments retry count and sets last attempted timestamp.
  Future<void> incrementEventRetry(String eventId) async {
    try {
      final db = await database;
      await db.rawUpdate(
        '''
        UPDATE ${AppConstants.tableAttendanceEvents}
        SET retry_count = retry_count + 1,
            last_attempted_at = ?
        WHERE id = ?
      ''',
        [DateTime.now().toIso8601String(), eventId],
      );
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to update event retry metadata',
        originalError: e,
      );
    }
  }

  // ==========================================
  // LEAVE LOCAL STORAGE METHODS
  // ==========================================

  /// Upserts leave balance for an employee.
  Future<void> upsertLeaveBalance(
    String employeeId,
    LeaveBalanceModel balance,
  ) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      await db.insert(
        AppConstants.tableLeaveBalances,
        {
          'employee_id': employeeId,
          'casual_leave': balance.casualLeave,
          'sick_leave': balance.sickLeave,
          'total_available_leave': balance.totalAvailableLeave,
          'last_updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to cache leave balance',
        originalError: e,
      );
    }
  }

  /// Retrieves cached leave balance.
  Future<LeaveBalanceModel?> getLeaveBalance(String employeeId) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableLeaveBalances,
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return LeaveBalanceModel.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to retrieve cached leave balance',
        originalError: e,
      );
    }
  }

  /// Bulk upserts leave requests into cache within a transaction.
  Future<void> upsertLeaveRequests(List<LeaveModel> requests) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final req in requests) {
          batch.insert(AppConstants.tableLeaves, {
            'id': req.id,
            'employee_id': req.employeeId,
            'leave_type': req.leaveType,
            'start_date': req.startDate,
            'end_date': req.endDate,
            'reason': req.reason,
            'status': req.status,
            'last_updated_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to batch save leave requests',
        originalError: e,
      );
    }
  }

  /// Retrieves cached leave requests for an employee.
  Future<List<LeaveModel>> getLeaveRequests(String employeeId) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableLeaves,
        where: 'employee_id = ?',
        whereArgs: [employeeId],
        orderBy: 'start_date DESC',
      );

      return maps.map((e) => LeaveModel.fromJson(e)).toList();
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to retrieve cached leave requests',
        originalError: e,
      );
    }
  }

  /// Retrieves active (Pending or Approved) leave requests to validate date overlaps.
  Future<List<LeaveModel>> getActiveLeaveRequests(String employeeId) async {
    try {
      final db = await database;
      final maps = await db.query(
        AppConstants.tableLeaves,
        where: 'employee_id = ? AND (status = ? OR status = ?)',
        whereArgs: [employeeId, 'Pending', 'Approved'],
        orderBy: 'start_date ASC',
      );

      return maps.map((e) => LeaveModel.fromJson(e)).toList();
    } catch (e) {
      throw LocalDatabaseException(
        message: 'Failed to retrieve active leave requests',
        originalError: e,
      );
    }
  }
}
