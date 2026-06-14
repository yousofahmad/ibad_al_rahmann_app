import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran_audio/logic/quran_player/quran_player_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/surah_list.dart';

class SurahWidget extends StatelessWidget {
  const SurahWidget({
    super.key,
    required this.index,
    // required this.surah,
    required this.selected,
  });

  final int index;
  // final SurahAudioModel surah;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        width: 320.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 8),
              width: context.isLandscape ? 80.h : 40.w,
              height: context.isLandscape ? 80.h : 40.w,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(AppAssets.imagesVerseFrame),
                ),
              ),
              child: Center(
                child: Text(
                  index.toArabicNums,
                  style: AppStyles.style16BFantezy.copyWith(
                    color: const Color(0xff606060),
                    fontSize: !context.isTablet ? 20.sp : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Text(
              quranSurahs[index - 1],
              style: AppStyles.style24harmattan.copyWith(
                color: const Color(0xff606060),
              ),
            ),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                context.read<QuranPlayerCubit>().playSurah(index);
              },
              color: AppColors.green,
              iconSize: 30.w,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: selected
                    ? Icon(Icons.pause_circle_filled_rounded, size: 42.w)
                    : Image.asset(
                        AppAssets.imagesPlayIcon,
                        width: 35.w,
                        fit: BoxFit.scaleDown,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
