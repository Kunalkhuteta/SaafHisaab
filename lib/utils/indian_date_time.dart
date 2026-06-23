class IndianDateTime {
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Returns the current date and time in Indian Standard Time (IST), represented as a UTC DateTime.
  static DateTime now() {
    return DateTime.now().toUtc().add(istOffset);
  }

  /// Returns the current instant in UTC.
  static DateTime nowUtc() {
    return DateTime.now().toUtc();
  }

  /// Creates a timezone-neutral UTC date.
  static DateTime date(int year, [int month = 1, int day = 1, int hour = 0, int minute = 0, int second = 0, int millisecond = 0, int microsecond = 0]) {
    return DateTime.utc(year, month, day, hour, minute, second, millisecond, microsecond);
  }

  /// Parses a string and returns a DateTime object adjusted to Indian Standard Time, represented as a UTC DateTime.
  /// If the string is a date-only string like "YYYY-MM-DD", it parses it directly as UTC to prevent timezone shifts.
  static DateTime parse(String dateStr) {
    if (dateStr.length == 10 && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
      return DateTime.parse('${dateStr}T00:00:00Z');
    }
    final parsed = DateTime.parse(dateStr);
    if (parsed.isUtc) {
      return parsed.add(istOffset);
    } else {
      return DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      );
    }
  }

  /// Tries to parse a string, returning null if parsing fails.
  static DateTime? tryParse(String? dateStr) {
    if (dateStr == null) return null;
    try {
      return parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Converts any existing DateTime object to a UTC representation of Indian Standard Time.
  static DateTime toIndian(DateTime dt) {
    if (dt.isUtc) {
      return dt.add(istOffset);
    } else {
      return DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
    }
  }
}
