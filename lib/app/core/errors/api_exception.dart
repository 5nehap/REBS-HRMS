class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({required this.message, this.statusCode, this.data});

  @override
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
}

class ValidationException extends ApiException {
  final List<String> errors;

  ValidationException({
    required super.message,
    super.statusCode = 422,
    this.errors = const [],
    super.data,
  });
}

class ConflictException extends ApiException {
  final String? conflictType;

  ConflictException({
    required super.message,
    super.statusCode = 409,
    this.conflictType,
    super.data,
  });
}

class NetworkException extends ApiException {
  NetworkException({required super.message, super.statusCode, super.data});
}

class ServerException extends ApiException {
  ServerException({required super.message, super.statusCode = 500, super.data});
}

/// Centralized professional error handler translating technical network failures
/// into user-friendly messages for attendance, leave, and application operations.
class NetworkErrorHandler {
  NetworkErrorHandler._();

  /// User-friendly message for attendance sync/submission failures
  static String getAttendanceErrorMessage(dynamic error) {
    if (error is NetworkException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('timeout') || msg.contains('timed out')) {
        return 'The server is taking longer than expected. Your attendance is saved and will be retried.';
      }
      return 'Unable to connect to the server. Your attendance is safely saved on this device.';
    }

    if (error is ConflictException) {
      return error.message.isNotEmpty
          ? error.message
          : 'Attendance event conflict detected. Record already registered.';
    }

    if (error is ValidationException) {
      return error.errors.isNotEmpty
          ? error.errors.join('\n')
          : error.message;
    }

    if (error is ServerException) {
      return 'Something went wrong on the server. Please try again later.';
    }

    if (error is ApiException) {
      return error.message;
    }

    return 'Attendance saved locally. It will sync when the server is available.';
  }

  /// User-friendly message for leave application failures
  static String getLeaveErrorMessage(dynamic error) {
    if (error is NetworkException) {
      return 'Leave applications require an internet connection and an available server. Please try again when connected.';
    }

    if (error is ValidationException) {
      return error.errors.isNotEmpty
          ? error.errors.join('\n')
          : error.message;
    }

    if (error is ConflictException) {
      return error.message.isNotEmpty
          ? error.message
          : 'Dates overlap with an existing leave request.';
    }

    if (error is ServerException) {
      return 'Something went wrong on the server. Please try again later.';
    }

    if (error is ApiException) {
      return error.message;
    }

    return 'Leave applications require an internet connection and an available server. Please try again when connected.';
  }
}
