import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/date_time_ext.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/widgets/adaptive_layout.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_images.dart';
import '../../../../core/theme/app_styles.dart';
import '../../data/models/prayer_times_model.dart';

class PrayerTimesDateWidget extends StatelessWidget {
  const PrayerTimesDateWidget({super.key, required this.prayers});

  final PrayerTimesResponseModel prayers;

  @override
  Widget build(BuildContext context) {
    return AdaptiveLayout(
      mobileLayout: (_) => MobilePrayerTimesDateWidget(prayers: prayers),
      tabletLayout: (_) => TabletPrayerTimesDateWidget(prayers: prayers),
    );
  }
}

class MobilePrayerTimesDateWidget extends StatelessWidget {
  const MobilePrayerTimesDateWidget({super.key, required this.prayers});

  final PrayerTimesResponseModel prayers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 22.h),
      width: context.screenWidth * .82,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        image: const DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage(AppImages.imagesGreenColor),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10.w,
            children: [
              Text(
                DateTime.now().toArabicWeekdayName,
                style: AppStyles.style26expo,
              ),
              Text(
                context.isLandscape ? '$title1 | $title2' : title1,
                style: AppStyles.style24harmattan.copyWith(
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          if (!context.isLandscape)
            Text(
              title2,
              style: AppStyles.style24harmattan.copyWith(
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }

  String get title1 {
    String day = DateTime.now().day.toArabicNums;
    if (DateTime.now().day < 10) {
      day = '٠$day';
    }
    return '$day ${DateTime.now().arabicMonth}';
  }

  String get title2 {
    return '${prayers.hijriDate.day.toArabicNums} ${prayers.hijriDate.monthName} ${prayers.hijriDate.year.toArabicNums}هـ';
  }
}

class TabletPrayerTimesDateWidget extends StatelessWidget {
  const TabletPrayerTimesDateWidget({super.key, required this.prayers});

  final PrayerTimesResponseModel prayers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18.h),
      width: context.screenWidth * .75,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        image: const DecorationImage(
          fit: BoxFit.cover,
          image: AssetImage(AppImages.imagesGreenColor),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10.w,
            children: [
              Text(
                DateTime.now().toArabicWeekdayName,
                style: AppStyles.style22expo,
              ),
              Text(
                context.isLandscape ? '$title1 | $title2' : title1,
                style: AppStyles.style18harmattan,
              ),
            ],
          ),
          if (!context.isLandscape)
            Text(title2, style: AppStyles.style18harmattan),
        ],
      ),
    );
  }

  String get title1 {
    String day = DateTime.now().day.toArabicNums;
    if (DateTime.now().day < 10) {
      day = '٠$day';
    }
    return '$day ${DateTime.now().arabicMonth}';
  }

  String get title2 {
    return '${prayers.hijriDate.day.toArabicNums} ${prayers.hijriDate.monthName} ${prayers.hijriDate.year.toArabicNums}هـ';
  }
}
