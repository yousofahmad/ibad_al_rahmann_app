import 'package:intl/intl.dart';

extension DateTimeExt on DateTime {
  String get toPrayerTime {
    return DateFormat('hh:mm a', 'ar').format(this);
  }

  String get toSimpleDate {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inSeconds < 60) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة${difference.inMinutes == 1
          ? ''
          : difference.inMinutes < 11
          ? ''
          : ''}';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة${difference.inHours == 1
          ? ''
          : difference.inHours < 11
          ? ''
          : ''}';
    } else if (difference.inDays < 30) {
      return 'منذ ${difference.inDays} يوم${difference.inDays == 1
          ? ''
          : difference.inDays < 11
          ? ''
          : ''}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'منذ $months شهر${months == 1
          ? ''
          : months < 11
          ? ''
          : ''}';
    } else {
      final years = (difference.inDays / 365).floor();
      return 'منذ $years سنة${years == 1
          ? ''
          : years < 11
          ? ''
          : ''}';
    }
  }

  String get arabicMonth {
    switch (month) {
      case 1:
        return 'يناير';
      case 2:
        return 'فبراير';
      case 3:
        return 'مارس';
      case 4:
        return 'أبريل';
      case 5:
        return 'مايو';
      case 6:
        return 'يونيو';
      case 7:
        return 'يوليو';
      case 8:
        return 'أغسطس';
      case 9:
        return 'سبتمبر';
      case 10:
        return 'أكتوبر';
      case 11:
        return 'نوفمبر';
      case 12:
        return 'ديسمبر';
      default:
        return '';
    }
  }

  String get toArabicWeekdayName {
    const days = {
      1: 'الاثنين',
      2: 'الثلاثاء',
      3: 'الأربعاء',
      4: 'الخميس',
      5: 'الجمعة',
      6: 'السبت',
      7: 'الأحد',
    };

    if (weekday < 1 || weekday > 7) {
      throw ArgumentError('يجب أن يكون رقم اليوم بين 1 و 7');
    }

    return days[weekday]!;
  }
}
