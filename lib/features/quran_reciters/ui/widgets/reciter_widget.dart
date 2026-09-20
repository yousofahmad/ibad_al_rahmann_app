import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran_audio/ui/quran_audio_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:zoom_tap_animation/zoom_tap_animation.dart';

import '../../data/models/reciter_model.dart';

class ReciterWidget extends StatelessWidget {
  const ReciterWidget({super.key, required this.reciter});
  final ReciterAudioModel reciter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

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
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: primaryColor.withValues(alpha: isDark ? 0.35 : 0.25),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : primaryColor.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  Icons.headphones_rounded,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reciter.name,
                      style: TextStyle(
                        fontFamily: AppConsts.expoArabic,
                        fontSize: (context.isTablet || context.isLandscape)
                            ? 16.5.sp
                            : 15.5.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            reciter.style,
                            style: TextStyle(
                              fontFamily: AppConsts.cairo,
                              color: primaryColor,
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: reciter.hasSegments
                                ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.15)
                                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                reciter.hasSegments
                                    ? Icons.auto_stories_rounded
                                    : Icons.library_music_rounded,
                                size: 11.sp,
                                color: reciter.hasSegments
                                    ? primaryColor
                                    : (isDark ? Colors.white70 : Colors.black54),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                reciter.hasSegments
                                    ? 'أصوات متقسمة آيات'
                                    : 'سورة كاملة',
                                style: TextStyle(
                                  fontFamily: AppConsts.cairo,
                                  color: reciter.hasSegments
                                      ? primaryColor
                                      : (isDark ? Colors.white70 : Colors.black54),
                                  fontSize: 9.5.sp,
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
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: isDark ? Colors.white38 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
