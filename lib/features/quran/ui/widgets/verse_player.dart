import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/reciter_dropdown.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart';
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
  const PortraitVersePlayer({super.key, required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VersePlayerCubit>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.lime.withAlpha(200),
            borderRadius: BorderRadius.circular(24),
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 16.w),
              child: Column(
                spacing: 4.h,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    spacing: 30.w,
                    children: [
                      ReciterDropdown(cubit: cubit),
                      IconButton(
                        onPressed: () {
                          cubit.hide();
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20.sp,
                          color: context.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      cubit.handlePlayPause();
                    },
                    iconSize: 55.w,
                    icon: isLoading
                        ? const CircularProgressIndicator()
                        : Icon(
                            getIt<AudioPlayer>().playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                            size: context.isTablet ? 50.w : null,
                          ),
                  ),
                  Text(
                    'سورة ${getSurahNameArabic(cubit.currnetVerse?.surahNumber ?? 1)}, الآية: ${(cubit.currnetVerse?.verseNumber ?? 0).toArabicNums}',
                    style: AppStyles.style16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LandscapeVersePlayer extends StatelessWidget {
  const LandscapeVersePlayer({super.key, required this.isLoading});
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VersePlayerCubit>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.lime.withAlpha(200),
            borderRadius: BorderRadius.circular(24),
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
              child: Column(
                spacing: 4.h,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    spacing: 30.w,
                    children: [
                      ReciterDropdown(cubit: cubit),
                      IconButton(
                        onPressed: () {
                          cubit.hide();
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20.sp,
                          color: context.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    onLongPress: () {},
                    onPressed: () {
                      cubit.handlePlayPause();
                    },
                    iconSize: context.isTablet ? 55.w : 30.w,
                    icon: isLoading
                        ? const CircularProgressIndicator()
                        : Icon(
                            getIt<AudioPlayer>().playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                          ),
                  ),
                  Text(
                    'سورة ${getSurahNameArabic(cubit.currnetVerse?.surahNumber ?? 1)}, الآية: ${(cubit.currnetVerse?.verseNumber ?? 0).toArabicNums}',
                    style: AppStyles.style16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
