import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/errors/api_exception.dart';
import '../core/services/connectivity_service.dart';
import '../data/models/attendance_event_model.dart';
import '../data/repositories/attendance_repository.dart';

enum SyncItemResult { synced, pending, rejected }

class SyncExecutionSummary {
  final int totalCount;
  final int syncedCount;
  final int pendingCount;
  final int rejectedCount;
  final String? firstError;

  SyncExecutionSummary({
    required this.totalCount,
    required this.syncedCount,
    required this.pendingCount,
    required this.rejectedCount,
    this.firstError,
  });

  bool get hasChanges => syncedCount > 0 || rejectedCount > 0;
  bool get allSynced => totalCount > 0 && syncedCount == totalCount;
}

class SyncLogic {
  final AttendanceRepository attendanceRepository;
  final ConnectivityService connectivityService;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  SyncLogic({
    required this.attendanceRepository,
    required this.connectivityService,
  });

  /// Check whether synchronization should run based on network connectivity
  bool shouldTriggerSync() {
    return connectivityService.isOnline.value && !_isSyncing;
  }

  /// Synchronizes all pending attendance events for an employee.
  /// Enforces:
  /// 1. Concurrency guard (prevents overlapping sync runs).
  /// 2. FIFO insertion ordering (retrieved ordered by created_at ASC).
  /// 3. CHECK_IN before CHECK_OUT for the same working day.
  /// 4. Preservation of original event ID, timestamp, coordinates.
  /// 5. Network / timeout error keeps event Pending and increments retry metadata.
  /// 6. Permanent 4xx (e.g. 422 geofence/order, or 409 already checked in) marks event Rejected.
  /// 7. A rejected Check In prevents dependent Check Out from attempting invalid synchronization.
  Future<SyncExecutionSummary> synchronizePendingAttendanceEvents(
    String employeeId,
  ) async {
    if (_isSyncing) {
      debugPrint('[SyncLogic] Sync is already in progress. Skipping request.');
      return SyncExecutionSummary(
        totalCount: 0,
        syncedCount: 0,
        pendingCount: 0,
        rejectedCount: 0,
        firstError: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    int syncedCount = 0;
    int pendingCount = 0;
    int rejectedCount = 0;
    String? firstErrorMessage;
    final rejectedDates = <String, String>{};

    try {
      // 1. Fetch pending events from persistent SQLite queue
      final pendingEvents = await attendanceRepository.getPendingEvents(
        employeeId,
      );

      if (pendingEvents.isEmpty) {
        debugPrint('[SyncLogic] No pending events to synchronize.');
        return SyncExecutionSummary(
          totalCount: 0,
          syncedCount: 0,
          pendingCount: 0,
          rejectedCount: 0,
        );
      }

      // 2. Stable sort ensuring CHECK_IN is processed before CHECK_OUT for the same working day
      final sortedEvents = List<AttendanceEventModel>.from(pendingEvents);
      sortedEvents.sort((a, b) {
        if (a.workingDate == b.workingDate) {
          if (a.eventType == AppConstants.eventCheckIn &&
              b.eventType == AppConstants.eventCheckOut) {
            return -1;
          }
          if (a.eventType == AppConstants.eventCheckOut &&
              b.eventType == AppConstants.eventCheckIn) {
            return 1;
          }
        }
        return a.createdAt.compareTo(b.createdAt);
      });

      debugPrint(
        '[SyncLogic] Synchronizing ${sortedEvents.length} pending events for employee $employeeId...',
      );

      for (final event in sortedEvents) {
        // If a preceding check-in for the same date was rejected, cascade rejection to check-out
        if (event.eventType == AppConstants.eventCheckOut &&
            rejectedDates.containsKey(event.workingDate)) {
          final parentReason = rejectedDates[event.workingDate]!;
          final rejectReason =
              'Check-Out rejected: Prior Check-In was rejected ($parentReason)';
          debugPrint(
            '[SyncLogic] Skipping network send for ${event.id}: $rejectReason',
          );
          await attendanceRepository.markEventRejected(event.id, rejectReason);
          rejectedCount++;
          firstErrorMessage ??= rejectReason;
          continue;
        }

        debugPrint(
          '[SyncLogic] Sending event ${event.id} (${event.eventType}) for date ${event.workingDate}...',
        );

        try {
          // Send event to backend using stable eventId
          final response = await attendanceRepository.postAttendanceEvent(
            event,
          );
          debugPrint(
            '[SyncLogic] Event ${event.id} accepted by backend: ${response["message"]}',
          );

          // Confirmed backend acceptance: mark Synced in local SQLite
          await attendanceRepository.markEventSynced(event.id);
          syncedCount++;
        } on NetworkException catch (e) {
          debugPrint(
            '[SyncLogic] Network / Timeout exception for event ${event.id}: ${e.message}',
          );
          // Keep Pending, update retry metadata, stop remaining queue to preserve sequential consistency
          await attendanceRepository.updateRetryMetadata(event.id);
          pendingCount++;
          firstErrorMessage ??= e.message;
          break;
        } on ConflictException catch (e) {
          debugPrint(
            '[SyncLogic] Conflict exception for event ${event.id}: ${e.message}',
          );
          final reason = e.message;
          await attendanceRepository.markEventRejected(event.id, reason);
          rejectedCount++;
          firstErrorMessage ??= reason;
          if (event.eventType == AppConstants.eventCheckIn) {
            rejectedDates[event.workingDate] = reason;
          }
        } on ValidationException catch (e) {
          debugPrint(
            '[SyncLogic] Validation exception for event ${event.id}: ${e.message}',
          );
          final reason = e.errors.isNotEmpty ? e.errors.join('\n') : e.message;
          await attendanceRepository.markEventRejected(event.id, reason);
          rejectedCount++;
          firstErrorMessage ??= reason;
          if (event.eventType == AppConstants.eventCheckIn) {
            rejectedDates[event.workingDate] = reason;
          }
        } on ApiException catch (e) {
          debugPrint(
            '[SyncLogic] API exception for event ${event.id}: ${e.message} (status: ${e.statusCode})',
          );
          if (e.statusCode != null &&
              e.statusCode! >= 400 &&
              e.statusCode! < 500) {
            // Permanent client error -> mark rejected
            await attendanceRepository.markEventRejected(event.id, e.message);
            rejectedCount++;
            firstErrorMessage ??= e.message;
            if (event.eventType == AppConstants.eventCheckIn) {
              rejectedDates[event.workingDate] = e.message;
            }
          } else {
            // 5xx Server error -> keep pending for retry
            await attendanceRepository.updateRetryMetadata(event.id);
            pendingCount++;
            firstErrorMessage ??= e.message;
            break;
          }
        } catch (e) {
          debugPrint('[SyncLogic] Unexpected error for event ${event.id}: $e');
          await attendanceRepository.updateRetryMetadata(event.id);
          pendingCount++;
          firstErrorMessage ??= e.toString();
          break;
        }
      }

      return SyncExecutionSummary(
        totalCount: sortedEvents.length,
        syncedCount: syncedCount,
        pendingCount: pendingCount,
        rejectedCount: rejectedCount,
        firstError: firstErrorMessage,
      );
    } finally {
      _isSyncing = false;
    }
  }
}
