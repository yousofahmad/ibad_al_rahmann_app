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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            AppImages.ayaFrame,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                getSurahNameArabic(surahNumber),
                textAlign: TextAlign.center,
                style: context.headlineMedium.copyWith(
                  fontSize: context.isTablet ? 22.sp : 20.sp,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
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
