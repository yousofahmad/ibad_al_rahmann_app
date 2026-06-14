import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/di/di.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/ui/widgets/audio/reciter_dropdown.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
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
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 6.h,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 20.w,
                  children: [
                    ReciterDropdown(cubit: cubit),
                    IconButton(
                      onPressed: () {
                        cubit.hide();
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20.sp,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                _PlayButton(isLoading: isLoading, cubit: cubit),
                if (cubit.currnetVerse != null)
                  _VerseTextDisplay(verse: cubit.currnetVerse!),
              ],
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
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 4.h,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 20.w,
                  children: [
                    ReciterDropdown(cubit: cubit),
                    IconButton(
                      onPressed: () {
                        cubit.hide();
                      },
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18.sp,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                _PlayButton(
                  isLoading: isLoading,
                  cubit: cubit,
                  isLandscape: true,
                ),
                if (cubit.currnetVerse != null)
                  _VerseTextDisplay(verse: cubit.currnetVerse!),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isLoading;
  final VersePlayerCubit cubit;
  final bool isLandscape;

  const _PlayButton({
    required this.isLoading,
    required this.cubit,
    this.isLandscape = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.zero,
      onPressed: () {
        cubit.handlePlayPause();
      },
      iconSize: isLandscape
          ? (context.isTablet ? 55.w : 40.w)
          : (context.isTablet ? 70.w : 55.w),
      icon: isLoading
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : Icon(
              getIt<AudioPlayer>().playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: Colors.white, // FIX: Explicit color
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
      constraints: BoxConstraints(maxWidth: context.screenWidth * 0.82),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'سورة ${getSurahNameArabic(verse.surahNumber)}, الآية: ${verse.verseNumber.toArabicNums}',
            style: AppStyles.style16.copyWith(
              fontSize: 13.sp,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            verse.verse,
            style: TextStyle(
              fontFamily: verse.fontFamily,
              fontSize: 17.sp,
              height: 1.4,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            // Removed maxLines to allow natural wrapping
          ),
        ],
      ),
    );
  }
}
