import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';

import '../../../../../core/theme/app_images.dart';

class FullHeaderWidget extends StatelessWidget {
  final int surahNumber;
  final Color? color;

  const FullHeaderWidget({super.key, required this.surahNumber, this.color});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              AppImages.ayaFrame,
              width: MediaQuery.of(context).size.width * 0.95,
              fit: BoxFit.contain,
              color: color,
            ),
            Text(
              textAlign: TextAlign.center,
              getSurahNameArabic(surahNumber),
              style: context.headlineMedium.copyWith(
                fontSize: context.isTablet ? 16.sp : null,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MinHeaderWidget extends StatelessWidget {
  final int surahNumber;
  final Color? color;

  const MinHeaderWidget({super.key, required this.surahNumber, this.color});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Stack(
        children: [
          Center(
            child: Image.asset(
              AppImages.ayaFrame,
              width: MediaQuery.of(context).size.width,
              color: color,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Center(
                child: Text(
                  textAlign: TextAlign.center,
                  getSurahNameArabic(surahNumber),
                  style: context.labelSmall.copyWith(
                    fontSize: context.isTablet ? 10.sp : 14.sp,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
