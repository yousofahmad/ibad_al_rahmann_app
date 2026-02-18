import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_images.dart';
import '../../../../core/widgets/top_bar_widget.dart';

class PrayerTimesHeader extends StatelessWidget {
  const PrayerTimesHeader({super.key, required this.isMorning});
  final bool isMorning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: context.screenWidth,
      child: Stack(
        children: [
          TopBar(
            image: isMorning
                ? AppImages.imagesMorningBackground
                : AppImages.imagesEveningBackground,
            height: context.isLandscape
                ? 350.h
                : context.isTablet
                ? 255.h
                : 210.h,
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                right: 20.w,
                top: context.isTabOrLand ? 30.h : 15.h,
              ),
              child: SvgPicture.asset(
                AppImages.svgsPrayersTitle,
                width: context.isLandscape
                    ? context.screenWidth * .22
                    : context.screenWidth * .34,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
