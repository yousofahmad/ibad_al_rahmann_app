import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_images.dart';
import '../../../../core/theme/app_styles.dart';

class UserLocationWidget extends StatelessWidget {
  const UserLocationWidget({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8.h),
      width: context.screenWidth * .8,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(30)),
        image: DecorationImage(
          image: AssetImage(AppImages.imagesGreenColor),
          fit: BoxFit.cover,
        ),
      ),
      child: Row(
        spacing: 10,
        children: [
          SvgPicture.asset(
            AppImages.svgsLocation,
            width: context.isLandscape ? 24.w : 30.w,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          Expanded(
            child: Text(
              location,
              style: AppStyles.style16.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: context.isTablet ? 12.sp : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
