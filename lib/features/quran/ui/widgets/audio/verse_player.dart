import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/audio/reciter_dropdown.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:quran/quran.dart';

class VersePlayer extends StatelessWidget {
  const VersePlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VersePlayerCubit, VersePlayerState>(
      builder: (context, state) {
        return AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: state.showed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          secondChild: const SizedBox(),
          firstChild: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: context.isLandscape
                ? LandscapeVersePlayer(isLoading: state.loading)
                : PortraitVersePlayer(isLoading: state.loading),
          ),
        );
      },
    );
  }
}

class PortraitVersePlayer extends StatelessWidget {
  final bool isLoading;
  const PortraitVersePlayer({super.key, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VersePlayerCubit>();
    final primaryColor = Theme.of(context).primaryColor;
    final isPlaying = cubit.player.playing;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 14.w),
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 14.w),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Top Row: Reciter Selector + Mode Pill + Speed + Loop + Close
          Row(
            children: [
              Flexible(
                child: ReciterDropdown(cubit: cubit),
              ),
              SizedBox(width: 6.w),
              // Single Verse vs Continuous toggle pill
              InkWell(
                onTap: () => cubit.toggleAutoPlayNext(),
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: cubit.autoPlayNext
                        ? const Color(0xFFFFD54F).withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: cubit.autoPlayNext
                          ? const Color(0xFFFFD54F)
                          : Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cubit.autoPlayNext ? Icons.repeat_rounded : Icons.looks_one_rounded,
                        size: 13.sp,
                        color: cubit.autoPlayNext ? const Color(0xFFFFD54F) : Colors.white,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        cubit.autoPlayNext ? 'متتالي' : 'آية واحدة',
                        style: TextStyle(
                          fontFamily: AppConsts.expoArabic,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.bold,
                          color: cubit.autoPlayNext ? const Color(0xFFFFD54F) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 5.w),
              // Speed toggle
              InkWell(
                onTap: () {
                  final speeds = [0.75, 1.0, 1.25, 1.5];
                  final currIdx = speeds.indexOf(cubit.playbackSpeed);
                  final nextSpeed = speeds[(currIdx + 1) % speeds.length];
                  cubit.changePlaybackSpeed(nextSpeed);
                },
                borderRadius: BorderRadius.circular(16.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Text(
                    '${cubit.playbackSpeed}x',
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.w),
              // Loop verse toggle
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tight(Size(28.w, 28.w)),
                onPressed: () => cubit.toggleLoop(),
                icon: Icon(
                  cubit.isLooping ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  size: 18.sp,
                  color: cubit.isLooping ? const Color(0xFFFFD54F) : Colors.white.withValues(alpha: 0.7),
                ),
                tooltip: cubit.isLooping ? 'تكرار الآية مفعل' : 'تكرار الآية معطل',
              ),
              SizedBox(width: 2.w),
              // Close button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tight(Size(28.w, 28.w)),
                onPressed: () => cubit.hide(),
                icon: Icon(Icons.close_rounded, size: 18.sp, color: Colors.white),
              ),
            ],
          ),

          SizedBox(height: 6.h),

          // Middle Row: Previous Verse · Play/Pause · Next Verse
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => cubit.playPreviousVerse(),
                icon: Icon(
                  Icons.skip_next_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 32.sp,
                ),
                tooltip: 'الآية السابقة',
              ),
              SizedBox(width: 12.w),
              IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => cubit.handlePlayPause(),
                iconSize: 52.sp,
                icon: isLoading
                    ? SizedBox(
                        width: 32.w,
                        height: 32.w,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(
                        isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                        color: Colors.white,
                      ),
              ),
              SizedBox(width: 12.w),
              IconButton(
                onPressed: () => cubit.playNextVerse(),
                icon: Icon(
                  Icons.skip_previous_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 32.sp,
                ),
                tooltip: 'الآية التالية',
              ),
            ],
          ),

          if (cubit.currnetVerse != null) ...[
            SizedBox(height: 4.h),
            _VerseTextDisplay(verse: cubit.currnetVerse!),
          ],
        ],
      ),
    );
  }
}

class LandscapeVersePlayer extends StatelessWidget {
  final bool isLoading;
  const LandscapeVersePlayer({super.key, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VersePlayerCubit>();
    final primaryColor = Theme.of(context).primaryColor;
    final isPlaying = cubit.player.playing;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReciterDropdown(cubit: cubit),
          SizedBox(width: 8.w),
          // Single Verse vs Continuous toggle pill
          InkWell(
            onTap: () => cubit.toggleAutoPlayNext(),
            borderRadius: BorderRadius.circular(16.r),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: cubit.autoPlayNext
                    ? const Color(0xFFFFD54F).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(
                  color: cubit.autoPlayNext
                      ? const Color(0xFFFFD54F)
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cubit.autoPlayNext ? Icons.repeat_rounded : Icons.looks_one_rounded,
                    size: 13.sp,
                    color: cubit.autoPlayNext ? const Color(0xFFFFD54F) : Colors.white,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    cubit.autoPlayNext ? 'متتالي' : 'آية واحدة',
                    style: TextStyle(
                      fontFamily: AppConsts.expoArabic,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.bold,
                      color: cubit.autoPlayNext ? const Color(0xFFFFD54F) : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 8.w),
          IconButton(
            onPressed: () => cubit.playPreviousVerse(),
            icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: 26.sp),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => cubit.handlePlayPause(),
            iconSize: 40.sp,
            icon: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Icon(
                    isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: Colors.white,
                  ),
          ),
          IconButton(
            onPressed: () => cubit.playNextVerse(),
            icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 26.sp),
          ),
          SizedBox(width: 8.w),
          IconButton(
            onPressed: () => cubit.hide(),
            icon: Icon(Icons.close_rounded, color: Colors.white, size: 20.sp),
          ),
        ],
      ),
    );
  }
}

class _VerseTextDisplay extends StatelessWidget {
  final VerseModel verse;

  const _VerseTextDisplay({required this.verse});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.screenWidth * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'سورة ${getSurahNameArabic(verse.surahNumber)} • الآية ${verse.verseNumber.toArabicNums}',
            style: AppStyles.style16.copyWith(
              fontSize: 12.sp,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            verse.verse,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: verse.fontFamily,
              fontSize: 15.sp,
              height: 1.3,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}
