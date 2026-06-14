import 'package:hijri/hijri_calendar.dart';

enum FastingType {
  monday,
  thursday,
  whiteDay,
  ashura,
  tasua,
  arafah,
  dhuAlHijjah,
  shawwal,
  other,
}

class FastingDay {
  final String title;
  final DateTime date;
  final HijriCalendar hijriDate;
  final FastingType type;
  final String? description;

  FastingDay({
    required this.title,
    required this.date,
    required this.hijriDate,
    required this.type,
    this.description,
  });
}
