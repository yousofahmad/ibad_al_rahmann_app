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
  const FehresItemsListView({
    super.key,
    required this.surahs,
    this.onSurface,
  });
  final List<SearchingSurahModel> surahs;
  final Color? onSurface;

  @override
  Widget build(BuildContext context) {
    if (surahs.isEmpty) {
      return ListView.builder(
        itemCount: 8,
        itemBuilder: (_, __) => AppSkeleton.indexItem(),
      );
    }
    final cubit = context.read<QuranCubit>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultOnSurface = onSurface ?? (isDarkMode ? Colors.white : Colors.black87);

    return ListView.separated(
      itemCount: surahs.length,
      separatorBuilder: (context, index) => Divider(
        color: defaultOnSurface.withValues(alpha: 0.12),
        height: 1,
      ),
      itemBuilder: (context, index) {
        final bool isActive =
            surahs.length == 114 && cubit.currentSurahIndex == index;
        final Color primary = Theme.of(context).primaryColor;
        final Color bgColor = isActive ? primary : Colors.transparent;

        // Force high contrast for active items based on primary color brightness
        final bool isPrimaryDark = ThemeData.estimateBrightnessForColor(primary) == Brightness.dark;
        final Color activeTextColor = isPrimaryDark ? Colors.white : Colors.black87;

        final Color textColor = isActive ? activeTextColor : defaultOnSurface;
        final Color subTextColor = isActive
            ? activeTextColor.withValues(alpha: 0.75)
            : defaultOnSurface.withValues(alpha: 0.65);

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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    Text(
                      surahs[index].surahNumber.toArabicNums,
                      style: TextStyle(
                        fontFamily: AppConsts.uthmanic,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'surah${surahs[index].surahNumber.toString().padLeft(3, '0')}',
                          style: TextStyle(
                            fontFamily: 'SurahNames',
                            color: textColor,
                            fontSize: 30,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          surahs[index].place,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            color: subTextColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'صفحة ${surahs[index].firstPage.toArabicNums}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: subTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'الجزء ${surahs[index].juzNumber.toArabicNums}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            color: subTextColor,
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
