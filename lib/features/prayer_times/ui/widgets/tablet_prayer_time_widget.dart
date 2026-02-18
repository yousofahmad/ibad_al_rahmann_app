import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/date_time_ext.dart';

import '../../../../core/theme/app_images.dart';
import '../../../../core/theme/app_styles.dart';
import '../../data/models/prayer_times_model.dart';

class PrayerTimeWidget extends StatelessWidget {
  const PrayerTimeWidget({
    super.key,
    required this.prayer,
    required this.isNextPrayer,
  });

  final PrayerTimeModel prayer;
  final bool isNextPrayer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: isNextPrayer
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              gradient: const LinearGradient(
                colors: [
                  Color.fromARGB(255, 10, 85, 79),
                  Color.fromARGB(255, 47, 68, 186),
                ],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
            )
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          image: const DecorationImage(
            fit: BoxFit.cover,
            image: AssetImage(AppImages.imagesGreenColor),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 2,
          children: [
            Text(prayer.title, style: AppStyles.style24harmattan),
            Text(prayer.date.toPrayerTime, style: AppStyles.style24harmattan),
            Text(
              '${prayer.prayerType == PrayerType.sunrise ? 'الإشراق' : 'الإقامة'}: ${prayer.iqamaDate.toPrayerTime}',
              style: AppStyles.style14harmattan,
            ),
          ],
        ),
      ),
    );
  }
}
