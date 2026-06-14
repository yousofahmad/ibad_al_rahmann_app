import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/search/search_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/surahs_tashkeel.dart';

import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';

class VerseSearchingBottomSheet extends StatelessWidget {
  const VerseSearchingBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final quranState = context.read<QuranCubit>().state;
    final paperColor = quranState.isWirdMode
        ? quranState.wirdPaperColor
        : quranState.quranPaperColor;
    
    final bool isPaperDark = (paperColor ?? Colors.white).computeLuminance() < 0.5;
    final dialogBg = isPaperDark ? const Color(0xFF000000) : Colors.white;
    final onSurface = isPaperDark ? Colors.white : Colors.black87;

    return Container(
      width: context.screenWidth,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        color: dialogBg,
      ),
      height: context.screenHeight * .75,
      child: BlocBuilder<SearchCubit, SearchState>(
        builder: (context, state) {
          if (state is OnSearch) {
            return Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  width: context.screenWidth,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.primaryColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Text(
                    'النتائج: ${state.verses.length.toArabicNums}',
                    style: context.titleSmall.copyWith(color: Colors.white),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    itemCount: state.verses.length,
                    itemBuilder: (context, index) {
                      final verse = state.verses[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        child: GestureDetector(
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            final quranCubit = context.read<QuranCubit>();
                            context.pop();
                            await quranCubit.navigateToVerse(
                              surahNumber: verse.surahNumber,
                              verseNumber: verse.verseNumber,
                            );
                          },
                          child: Column(
                            children: [
                              Text(
                                verse.content,
                                style: context.titleSmall.copyWith(
                                  fontFamily: AppConsts.amiri,
                                  fontSize: 20,
                                  color: onSurface,
                                ),
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.rtl,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'سورة ${surahArabicTashkel[verse.surahNumber - 1]} - الآية ${verse.verseNumber.toArabicNums}',
                                  style: context.labelSmall.copyWith(
                                    fontFamily: 'Cairo',
                                    color: onSurface.withAlpha(180),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Divider(color: onSurface.withAlpha(30)),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return ListView.builder(
              itemCount: 8,
              itemBuilder: (_, __) => AppSkeleton.indexItem(),
            );
          }
        },
      ),
    );
  }
}
