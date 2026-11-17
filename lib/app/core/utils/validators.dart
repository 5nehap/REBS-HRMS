class Validators {
  Validators._();

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null) {
      return 'Start date is required';
    }
    if (endDate == null) {
      return 'End date is required';
    }
    if (endDate.isBefore(startDate)) {
      return 'End date cannot be before start date';
    }
    return null;
  }

  static String? validateReason(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Reason is required';
    }
    if (value.trim().length < 5) {
      return 'Reason must be at least 5 characters long';
    }
    return null;
  }
}
