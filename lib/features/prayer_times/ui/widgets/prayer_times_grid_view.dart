import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/models/prayer_times_model.dart';
import 'mobile_prayer_time_widget.dart';

class PrayerTimesGridView extends StatelessWidget {
  const PrayerTimesGridView({
    super.key,
    required this.prayers,
    required this.nextPrayer,
  });

  final PrayerTimesResponseModel prayers;
  final PrayerTimeModel nextPrayer;
  @override
  Widget build(BuildContext context) {
    if (context.isLandscape) {
      return SliverGrid.builder(
        itemCount: prayers.prayerTimes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: 320.h,
          mainAxisSpacing: 20.h,
        ),
        itemBuilder: (context, index) {
          return PrayerTimeWidget(
            prayer: prayers.prayerTimes[index],
            isNextPrayer: prayers.prayerTimes[index].title == nextPrayer.title,
          );
        },
      );
    }
    return SliverGrid.builder(
      itemCount: prayers.prayerTimes.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: context.isTablet ? 180.h : 130.h,
        crossAxisSpacing: context.isTablet ? 24 : 16,
        mainAxisSpacing: context.isTablet ? 10.h : 6,
      ),
      itemBuilder: (context, index) {
        return PrayerTimeWidget(
          prayer: prayers.prayerTimes[index],
          isNextPrayer: prayers.prayerTimes[index].title == nextPrayer.title,
        );
      },
    );
  }
}


