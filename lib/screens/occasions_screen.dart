import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:intl/intl.dart';

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
    final now = DateTime.now();
    final adjustedDate = now.add(Duration(days: hijriOffset));
    final nowH = HijriCalendar.fromDate(adjustedDate);
    final int currentYear = nowH.hYear;

    // Calculate all events for the current Hijri year
    List<_IslamicEventDisplay> yearEvents = [];

    // Reference start of the CURRENT Hijri year
    final refStartH = HijriCalendar();
    refStartH.hYear = currentYear;
    refStartH.hMonth = 1;
    refStartH.hDay = 1;
    DateTime refStartG = refStartH
        .hijriToGregorian(currentYear, 1, 1)
        .subtract(Duration(days: hijriOffset));

    for (var event in _events) {
      final temp = HijriCalendar();
      DateTime gregDate = temp.hijriToGregorian(
        currentYear,
        event.hMonth,
        event.hDay,
      );
      gregDate = gregDate.subtract(Duration(days: hijriOffset));

      final nowGreg = DateTime(now.year, now.month, now.day);
      final eventGregOnly = DateTime(
        gregDate.year,
        gregDate.month,
        gregDate.day,
      );
      int daysDiff = eventGregOnly.difference(nowGreg).inDays;

      // If event passed this year, show it for next year
      if (daysDiff < 0) {
        gregDate = temp.hijriToGregorian(
          currentYear + 1,
          event.hMonth,
          event.hDay,
        );
        gregDate = gregDate.subtract(Duration(days: hijriOffset));
        daysDiff = DateTime(
          gregDate.year,
          gregDate.month,
          gregDate.day,
        ).difference(nowGreg).inDays;
      }

      final hDate = HijriCalendar.fromDate(
        gregDate.add(Duration(days: hijriOffset)),
      );

      // Progress calculation: Distance from CURRENT year start to event vs now
      double totalDaysFromRef = gregDate
          .difference(refStartG)
          .inDays
          .toDouble();
      double passedDaysFromRef = now.difference(refStartG).inDays.toDouble();
      double progress = (passedDaysFromRef / totalDaysFromRef).clamp(0.0, 1.0);

      yearEvents.add(
        _IslamicEventDisplay(event.title, daysDiff, hDate, gregDate, progress),
      );
    }

    // Sort by days left
    yearEvents.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const goldColor = Color(0xFFD0A871);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "المناسبات الإسلامية",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: goldColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: goldColor),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: yearEvents.length,
        itemBuilder: (context, index) {
          return _buildEventCard(
            yearEvents[index],
            isDark,
            goldColor,
            index == 0,
          );
        },
      ),
    );
  }

  Widget _buildEventCard(
    _IslamicEventDisplay event,
    bool isDark,
    Color goldColor,
    bool isNext,
  ) {
    final textColor = isDark ? Colors.white : Colors.black;

    // Enforce gold color as the active color for this screen per user request
    final Color activeColor = goldColor;

    // Background colors for the progress parts
    final Color filledPartColor = activeColor.withValues(
      alpha: isDark ? 0.25 : 0.15,
    );
    final Color emptyPartColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.grey.withValues(alpha: 0.05);

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isNext
              ? activeColor.withValues(alpha: 0.6)
              : Colors.grey.withValues(alpha: 0.2),
          width: isNext ? 2.0.w : 1.0.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Stack(
          children: [
            // Progress Fill Layer (Empty part as base)
            Positioned.fill(child: Container(color: emptyPartColor)),
            // Progress Fill Layer (Filled part)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: event.progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          filledPartColor,
                          filledPartColor.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content Layer
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(
                            fontFamily: AppConsts.expoArabic,
                            color: isNext ? activeColor : textColor,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              DateFormat(
                                'd MMMM yyyy',
                                'ar',
                              ).format(event.gregDate),
                              style: TextStyle(
                                fontFamily: AppConsts.cairo,
                                color: Colors.grey.shade600,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            Icon(
                              Icons.history_toggle_off_outlined,
                              size: 14.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              "${event.hijriDate.hDay} ${event.hijriDate.longMonthName} ${event.hijriDate.hYear}",
                              style: TextStyle(
                                fontFamily: AppConsts.cairo,
                                color: Colors.grey.shade600,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14.w,
                          vertical: 8.h,
                        ),
                        decoration: BoxDecoration(
                          color: isNext
                              ? activeColor
                              : activeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14.r),
                          boxShadow: isNext
                              ? [
                                  BoxShadow(
                                    color: activeColor.withValues(alpha: 0.3),
                                    blurRadius: 8.r,
                                    offset: Offset(0, 3.h),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          event.daysLeft == 0
                              ? "اليوم"
                              : "باقي ${event.daysLeft} يوم",
                          style: TextStyle(
                            fontFamily: AppConsts.cairo,
                            color: isNext ? Colors.white : activeColor,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        "${(event.progress * 100).toInt()}%",
                        style: TextStyle(
                          fontFamily: AppConsts.cairo,
                          color: activeColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
  final double progress;

  _IslamicEventDisplay(
    this.title,
    this.daysLeft,
    this.hijriDate,
    this.gregDate,
    this.progress,
  );
}
