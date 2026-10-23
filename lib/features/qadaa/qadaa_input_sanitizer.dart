class QadaaInputSanitizer {
  const QadaaInputSanitizer._();

  static int nonNegativeCount(int? value) =>
      value == null || value < 0 ? 0 : value;

  static double progress(int count, int maximum) {
    if (maximum <= 0) return 1.0;
    final value = 1.0 - (count / maximum);
    return value.clamp(0.0, 1.0).toDouble();
  }

  static ({int hour, int minute})? parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return (hour: hour, minute: minute);
  }

  static int month(int? value, {int fallback = 7}) =>
      value != null && value >= 1 && value <= 12 ? value : fallback;

  static int weekDay(int? value, {int fallback = 7}) =>
      value != null && value >= 1 && value <= 7 ? value : fallback;
}
