class LocalDatabaseException implements Exception {
  final String message;
  final dynamic originalError;

  LocalDatabaseException({required this.message, this.originalError});

  @override
  String toString() {
    if (originalError != null) {
      return 'LocalDatabaseException: $message (Caused by: $originalError)';
    }
    return 'LocalDatabaseException: $message';
  }
}
