import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/app_constants.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/search/search_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/surahs_tashkeel.dart';

class VerseSearchingBottomSheet extends StatelessWidget {
  const VerseSearchingBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: context.screenWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: context.onPrimary,
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
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.lime,
                  ),
                  child: Text(
                    'النتائج: ${state.verses.length.toArabicNums}',
                    style: context.titleSmall,
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
                          onTap: () {
                            context.read<QuranCubit>().navigateToVerse(
                                  surahNumber: verse.surahNumber,
                                  verseNumber: verse.verseNumber,
                                );
                            // Clear search query and results after navigating
                            context.read<SearchCubit>().clear();
                            // The bottom sheet will close when the search field empties
                            context.pop();
                          },
                          child: Column(
                            children: [
                              Text(
                                verse.content,
                                style: context.titleSmall,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'سورة ${surahArabicTashkel[verse.surahNumber - 1]} - الآية ${verse.verseNumber}',
                                  style: context.labelSmall.copyWith(
                                    fontFamily: AppConsts.uthmanic,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Divider(color: AppColors.greyYellow),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
