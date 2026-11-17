import 'package:intl/intl.dart';

class DateHelper {
  DateHelper._();

  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  static final DateFormat _displayDateTimeFormat = DateFormat(
    'dd MMM yyyy, hh:mm a',
  );

  static String formatDate(DateTime date) => _dateFormat.format(date);
  static String formatDisplayDate(DateTime date) =>
      _displayDateFormat.format(date);
  static String formatTime(DateTime time) => _timeFormat.format(time);
  static String formatDateTime(DateTime dateTime) =>
      _dateTimeFormat.format(dateTime);
  static String formatDisplayDateTime(DateTime dateTime) =>
      _displayDateTimeFormat.format(dateTime);

  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }
}
