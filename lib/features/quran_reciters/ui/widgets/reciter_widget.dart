import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran_audio/ui/quran_audio_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../../../../core/theme/app_assets.dart';
import '../../../../core/theme/app_styles.dart';
import '../../data/models/reciter_model.dart';

class ReciterWidget extends StatelessWidget {
  const ReciterWidget({super.key, required this.reciter});
  final ReciterAudioModel reciter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ZoomTapAnimation(
        end: .98,
        onTap: () {
          context.read<QuranPlayerCubit>().reciter = reciter;
          context.push(
            QuranAudioScreen(reciter: reciter),
            direction: NavigationDirection.downToUp,
          );
        },
        child: Container(
          width: 340.w,
          padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 20.w),
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage(AppAssets.imagesGreenColor),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reciter.name,
                      style: AppStyles.style22expo.copyWith(
                        fontSize: (context.isTablet || context.isLandscape)
                            ? 18.sp
                            : 16.5.sp,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            reciter.style,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: reciter.hasSegments
                                ? const Color(0xFFD0A871).withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                reciter.hasSegments
                                    ? Icons.auto_stories_rounded
                                    : Icons.library_music_rounded,
                                size: 12.sp,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                reciter.hasSegments
                                    ? 'أصوات متقسمة آيات'
                                    : 'سورة كاملة فقط',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
