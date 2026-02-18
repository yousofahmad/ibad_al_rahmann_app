import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';

class OccasionsScreen extends StatefulWidget {
  const OccasionsScreen({super.key});

  @override
  State<OccasionsScreen> createState() => _OccasionsScreenState();
}

class _OccasionsScreenState extends State<OccasionsScreen> {
  // Event Definition
  final List<_IslamicEvent> _events = [
    _IslamicEvent("رأس السنة الهجرية", 1, 1),
    _IslamicEvent("يوم عاشوراء", 1, 10),
    _IslamicEvent("بداية شهر رمضان", 9, 1),
    _IslamicEvent("عيد الفطر المبارك", 10, 1),
    _IslamicEvent("يوم عرفة", 12, 9),
    _IslamicEvent("عيد الأضحى المبارك", 12, 10),
  ];

  @override
  Widget build(BuildContext context) {
    // Current Date with user's hijri offset
    HijriCalendar.setLocal('ar');
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = DateTime.now().add(Duration(days: hijriOffset));
    final now = HijriCalendar.fromDate(adjustedDate);

    // Calculate days remaining for each event
    // We need to determine if the event is later this year or next year
    List<_IslamicEventDisplay> upcoming = [];

    for (var event in _events) {
      // Construct event date for CURRENT Hijri year
      // Note: HijriCalendar validity checks (month lengths) are complex.
      // We assume standard months for simplicity of "upcoming" check or use library comparison.

      // Simple logic: Compare (month, day) tuples.
      int currentVal = now.hMonth * 100 + now.hDay;
      int eventVal = event.hMonth * 100 + event.hDay;

      int targetYear = now.hYear;
      if (eventVal < currentVal) {
        // Event passed this year, so it's next year
        targetYear++;
      }

      // Calculate difference in days.
      // HijriCalendar doesn't have easy "difference".
      // We can convert both to Gregorian to get difference in days.
      var targetHijri = HijriCalendar();
      targetHijri.hYear = targetYear;
      targetHijri.hMonth = event.hMonth;
      targetHijri.hDay = event.hDay;

      // Convert to Gregorian to get accurate day diff
      DateTime targetGreg = targetHijri.hijriToGregorian(
        targetYear,
        event.hMonth,
        event.hDay,
      );
      DateTime nowGreg = DateTime.now();

      // Reset times for pure day diff
      nowGreg = DateTime(nowGreg.year, nowGreg.month, nowGreg.day);
      targetGreg = DateTime(targetGreg.year, targetGreg.month, targetGreg.day);

      int daysLeft = targetGreg.difference(nowGreg).inDays;

      upcoming.add(
        _IslamicEventDisplay(event.title, daysLeft, targetHijri, targetGreg),
      );
    }

    // Sort by nearest
    upcoming.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "المناسبات الإسلامية",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: Color(0xFFD0A871),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
      ),
      body: upcoming.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                // Nearest Event (Hero Card)
                _buildHeroCard(upcoming.first),

                SizedBox(height: 20.h),
                Text(
                  "المناسبات القادمة",
                  style: TextStyle(
                    fontFamily: AppConsts.expoArabic,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10.h),

                // Rest of events
                ...upcoming.skip(1).map((e) => _buildEventCard(e)),
              ],
            ),
    );
  }

  Widget _buildHeroCard(_IslamicEventDisplay event) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD0A871), Color(0xFFB88E50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0A871), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD0A871).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "الحدث القادم",
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.white70,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            event.title,
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.white,
              fontSize: 26.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            event.hijriDate.toFormat("dd MMMM yyyy"), // e.g: 10 Muharram 1446
            style: TextStyle(
              fontFamily: AppConsts.expoArabic,
              color: Colors.white70,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              "باقي ${event.daysLeft} يوم",
              style: TextStyle(
                fontFamily: AppConsts.expoArabic,
                color: Colors.white,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(_IslamicEventDisplay event) {
    // progress: Closer events have higher progress (more fill).
    // Assuming max range is a full year (355/365 days).
    double progress = (1.0 - (event.daysLeft / 355.0)).clamp(0.0, 1.0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF121212) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor = isDark ? Colors.white10 : Colors.grey.withAlpha(50);
    final circleColor = isDark ? Colors.black : Colors.grey.shade50;

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      // Clip needed for the background strip to respect border radius
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.grey.withAlpha(20),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Stack(
        children: [
          // Background Progress Strip
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight, // Fill from Right (Arabic)
              child: FractionallySizedBox(
                widthFactor: progress,
                heightFactor: 1.0,
                child: Container(
                  color: const Color(0xFFD0A871).withValues(alpha: 0.15),
                ),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  constraints: BoxConstraints(minWidth: 60.w, minHeight: 60.w),
                  decoration: BoxDecoration(
                    color: circleColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD0A871).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${event.daysLeft}",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: const Color(0xFFD0A871),
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        "يوم",
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: Colors.grey,
                          fontSize: 10.sp,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 15.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: textColor,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        event.hijriDate.toFormat("dd MMMM yyyy"),
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          color: Colors.grey,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IslamicEvent {
  final String title;
  final int hMonth;
  final int hDay;

  _IslamicEvent(this.title, this.hMonth, this.hDay);
}

class _IslamicEventDisplay {
  final String title;
  final int daysLeft;
  final HijriCalendar hijriDate;
  final DateTime gregDate;

  _IslamicEventDisplay(
    this.title,
    this.daysLeft,
    this.hijriDate,
    this.gregDate,
  );
}
