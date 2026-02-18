import 'package:ibad_al_rahmann/features/prayer_times/data/models/user_location_model.dart';

class HijriDate {
  final int year, month, day;
  final String monthName;

  HijriDate(
      {required this.year,
      required this.month,
      required this.day,
      required this.monthName});

  factory HijriDate.fromJson(Map<String, dynamic> json) {
    return HijriDate(
      year: int.parse(json['year']),
      month: json['month']['number'],
      day: int.parse(json['day']),
      monthName: months[json['month']['number']],
    );
  }
  static const months = [
    'محرم',
    'صفر',
    'ربيع الاول',
    'ربيع الثاني',
    'جمادى الاولى',
    'جمادى الاخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];
}

class PrayerTimesResponseModel {
  final UserLocationModel location;
  final List<PrayerTimeModel> prayerTimes;
  final HijriDate hijriDate;

  PrayerTimesResponseModel({
    required this.location,
    required this.prayerTimes,
    required this.hijriDate,
  });

  factory PrayerTimesResponseModel.fromJson(
    Map<String, dynamic> json, {
    required UserLocationModel location,
  }) {
    final Map<String, dynamic> timings = json['timings'];
    final finalPrayerTimes = [
      PrayerTimeModel.fromTime('Fajr', timings['Fajr']),
      PrayerTimeModel.fromTime('Sunrise', timings['Sunrise'],
          increment: location.isoCode == 'AE' ? -4 : 0),
      PrayerTimeModel.fromTime('Dhuhr', timings['Dhuhr']),
      PrayerTimeModel.fromTime('Asr', timings['Asr']),
      PrayerTimeModel.fromTime('Maghrib', timings['Maghrib']),
      PrayerTimeModel.fromTime('Isha', timings['Isha']),
    ];

    return PrayerTimesResponseModel(
      location: location,
      prayerTimes: finalPrayerTimes,
      hijriDate: HijriDate.fromJson(json['date']['hijri']),
    );
  }

  // static String _getHijriMonthName(int monthNumber) {

  //   if (monthNumber < 1 || monthNumber > 12) {
  //     throw ArgumentError('رقم الشهر الهجري يجب أن يكون بين 1 و 12');
  //   }

  //   return months[monthNumber - 1];
  // }
}

enum PrayerType {
  fajr(
    name: 'الفجر',
    incrementMinutes: 25,
  ),
  sunrise(
    name: 'الشروق',
    incrementMinutes: 20,
  ),
  dhuhr(
    name: 'الظهر',
    incrementMinutes: 20,
  ),
  asr(
    name: 'العصر',
    incrementMinutes: 20,
  ),
  maghrib(
    name: 'المغرب',
    incrementMinutes: 5,
  ),
  isha(
    name: 'العشاء',
    incrementMinutes: 20,
  );

  final String name;
  final int incrementMinutes;

  bool get isMorning {
    switch (this) {
      case PrayerType.fajr:
        return false;
      case PrayerType.sunrise:
        return true;

      case PrayerType.dhuhr:
        return true;

      case PrayerType.asr:
        return true;

      case PrayerType.maghrib:
        return false;

      case PrayerType.isha:
        return false;
    }
  }

  const PrayerType({
    required this.name,
    required this.incrementMinutes,
  });
}

class PrayerTimeModel {
  final PrayerType prayerType;
  final String title;
  final DateTime date, iqamaDate;

  PrayerTimeModel({
    required this.prayerType,
    required this.title,
    required this.date,
    required this.iqamaDate,
  });

  factory PrayerTimeModel.fromTime(String prayerName, String time,
      {int? increment}) {
    final prayerType = _getPrayerName(prayerName);
    return PrayerTimeModel(
      prayerType: prayerType,
      title: prayerType.name,
      date: _convertTimeStringToDateTime(time, incrementMinutes: increment),
      iqamaDate: _convertTimeStringToDateTime(
        time,
        incrementMinutes: prayerType.incrementMinutes,
      ),
    );
  }

  static PrayerType _getPrayerName(String prayerName) {
    switch (prayerName) {
      case 'Fajr':
        return PrayerType.fajr;
      case 'Sunrise':
        return PrayerType.sunrise;
      case 'Dhuhr':
        return PrayerType.dhuhr;
      case 'Asr':
        return PrayerType.asr;
      case 'Maghrib':
        return PrayerType.maghrib;
      case 'Isha':
        return PrayerType.isha;
      default:
        return PrayerType.fajr;
    }
  }

  static DateTime _convertTimeStringToDateTime(
    String timeString, {
    int? incrementMinutes,
  }) {
    try {
      // Split the time string by colon
      List<String> timeParts = timeString.split(':');

      if (timeParts.length != 2) {
        throw const FormatException(
            'Invalid time format. Expected format: "HH:mm"');
      }

      // Parse hour and minute
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      // Validate hour and minute ranges
      if (hour < 0 || hour > 23) {
        throw const FormatException('Hour must be between 0 and 23');
      }
      if (minute < 0 || minute > 59) {
        throw const FormatException('Minute must be between 0 and 59');
      }

      // Create DateTime with today's date and the specified time
      final now = DateTime.now();
      final finalDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (incrementMinutes != null) {
        return finalDate.add(Duration(minutes: incrementMinutes));
      } else {
        return finalDate;
      }
    } catch (e) {
      throw FormatException('Failed to parse time string "$timeString": $e');
    }
  }
}


