import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/searching_surah_model.dart';
import 'package:quran/quran.dart';

import 'package:ibad_al_rahmann/widgets/app_skeleton.dart';

class FehresItemsListView extends StatelessWidget {
  const FehresItemsListView({super.key, required this.surahs});
  final List<SearchingSurahModel> surahs;

  @override
  Widget build(BuildContext context) {
    if (surahs.isEmpty) {
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => AppSkeleton.indexItem(),
      );
    }
    final cubit = context.read<QuranCubit>();
    return ListView.separated(
      itemCount: surahs.length,
      separatorBuilder: (context, index) => Divider(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        height: 3,
      ),
      itemBuilder: (context, index) {
        // final surahFirstPage = getSurahPages(index + 1).first;
        // final juzNumber = getJuzNumber(index + 1, 1);
        final bool isActive =
            surahs.length == 114 && cubit.currentSurahIndex == index;
        final Color bgColor = isActive
            ? Theme.of(context).primaryColor
            : Colors.transparent;

        // Force high contrast for active items based on primary color brightness
        final bool isPrimaryDark = ThemeData.estimateBrightnessForColor(Theme.of(context).primaryColor) == Brightness.dark;
        final Color activeTextColor = isPrimaryDark ? Colors.white : Colors.black87;

        final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final Color primaryColored = isActive 
            ? activeTextColor 
            : (isDarkMode ? Colors.white70 : Theme.of(context).primaryColor);

        return GestureDetector(
          onTap: () {
            context.pop();
            cubit.navigateToVerse(
              surahNumber: surahs[index].surahNumber,
              verseNumber: 1,
            );
          },
          child: ColoredBox(
            color: bgColor,
            child: Padding(
              padding: const EdgeInsets.only(right: 20, left: 20, top: 8),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    Text(
                      surahs[index].surahNumber.toArabicNums,
                      style: AppStyles.style24u.copyWith(
                        fontSize: 24,
                        color: primaryColored,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'surah${surahs[index].surahNumber.toString().padLeft(3, '0')}',
                          style: TextStyle(
                            fontFamily: 'SurahNames',
                            color: primaryColored,
                            fontSize: 32,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          surahs[index].place,
                          style: AppStyles.style18u.copyWith(
                            color: primaryColored,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      spacing: 6,
                      children: [
                        Text(
                          'صفحة ${surahs[index].firstPage.toArabicNums}',
                          style: AppStyles.style14u.copyWith(
                            fontSize: 14,
                            color: primaryColored,
                          ),
                        ),
                        Text(
                          'الجزء ${surahs[index].juzNumber.toArabicNums}',
                          style: AppStyles.style14u.copyWith(
                            color: primaryColored,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String handlePlaceOfRevelation(int index) {
    return getPlaceOfRevelation(index + 1) == 'Makkah' ? 'مكية' : 'مدنية';
  }
}
