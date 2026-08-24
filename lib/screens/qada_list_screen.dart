import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:ibad_al_rahmann/services/prayer_service.dart';
import 'package:ibad_al_rahmann/core/helpers/cache_helper.dart';

class QadaListScreen extends StatefulWidget {
  const QadaListScreen({super.key});

  @override
  State<QadaListScreen> createState() => _QadaListScreenState();
}

class _QadaListScreenState extends State<QadaListScreen> {
  final Map<int, bool> _missedDays = {};
  int _currentRamadanYear = 1445;

  @override
  void initState() {
    super.initState();
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = DateTime.now().add(Duration(days: hijriOffset));
    final hijri = HijriCalendar.fromDate(adjustedDate);
    // Until the 1st of the next Ramadan (Month 9) arrives, we track the preceding Ramadan
    _currentRamadanYear = hijri.hMonth >= 9 ? hijri.hYear : hijri.hYear - 1;
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = CacheHelper.prefs;
    setState(() {
      for (int i = 1; i <= 30; i++) {
        _missedDays[i] =
            prefs.getBool('qada_${_currentRamadanYear}_$i') ?? false;
      }
    });
  }

  Future<void> _toggleDay(int day, bool? value) async {
    if (value == null) return;
    final prefs = CacheHelper.prefs;
    await prefs.setBool('qada_${_currentRamadanYear}_$day', value);
    setState(() {
      _missedDays[day] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hijriOffset = PrayerService().hijriOffset;
    final adjustedDate = DateTime.now().add(Duration(days: hijriOffset));
    HijriCalendar now = HijriCalendar.fromDate(adjustedDate);
    bool isRamadan = now.hMonth == 9;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          "سجل القضاء",
          style: TextStyle(
            fontFamily: AppConsts.expoArabic,
            color: const Color(0xFFD0A871),
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFFD0A871)),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "عدد الأيام الفائتة: ${_missedDays.values.where((e) => e).length}",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        color: isDark ? Colors.white : Colors.black,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "رمضان $_currentRamadanYear",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        color: const Color(0xFFD0A871),
                        fontSize: 14.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 30,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              itemBuilder: (context, index) {
                int day = index + 1;

                // Future Lock Logic:
                // Only lock days ahead of today IF we are currently in Ramadan.
                // Otherwise (months 10-12 and months 1-8 of the new year), all 30 days are past and active for Qadaa.
                bool isFuture = false;
                if (isRamadan) {
                  if (day > now.hDay) {
                    isFuture = true;
                  }
                }

                return Container(
                  margin: EdgeInsets.only(bottom: 10.h),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF000000) : Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                      width: 1.0.w,
                    ),
                    boxShadow: [
                      if (!isDark)
                        BoxShadow(
                          color: Colors.grey.withValues(alpha: 0.1),
                          blurRadius: 5.r,
                          offset: Offset(0, 2.h),
                        ),
                    ],
                  ),
                  child: ListTile(
                    enabled: !isFuture,
                    title: Text(
                      "رمضان $day",
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        color: isFuture
                            ? (isDark ? Colors.grey[700] : Colors.grey[400])
                            : (isDark ? Colors.white : Colors.black),
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                    ),
                    subtitle: isFuture
                        ? Text(
                            "لم يأتِ بعد",
                            style: TextStyle(
                              fontFamily: AppConsts.expoArabic,
                              color: Colors.grey[800],
                              fontSize: 10.sp,
                            ),
                          )
                        : null,
                    trailing: Transform.scale(
                      scale: 1.2,
                      child: Checkbox(
                        value: _missedDays[day] ?? false,
                        activeColor: const Color(0xFFD0A871),
                        fillColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const Color(0xFFD0A871);
                          }
                          return Colors.white24;
                        }),
                        checkColor: Colors.black,
                        onChanged: isFuture ? null : (v) => _toggleDay(day, v),
                        shape: const CircleBorder(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
