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
  ConflictException({
    required super.message,
    super.statusCode = 409,
    super.data,
  });
}

class NetworkException extends ApiException {
  NetworkException({required super.message, super.statusCode, super.data});
}

class ServerException extends ApiException {
  ServerException({required super.message, super.statusCode = 500, super.data});
}
