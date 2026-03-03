import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/searching_surah_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';

class FehresItemsListView extends StatelessWidget {
  const FehresItemsListView({super.key, required this.surahs});
  final List<SearchingSurahModel> surahs;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuranCubit>();
    return ListView.separated(
      itemCount: surahs.length,
      separatorBuilder: (context, index) =>
          Divider(color: Colors.grey.shade400, height: 3),
      itemBuilder: (context, index) {
        // final surahFirstPage = getSurahPages(index + 1).first;
        // final juzNumber = getJuzNumber(index + 1, 1);
        return GestureDetector(
          onTap: () {
            context.pop();
            cubit.navigateToSurah(surahs[index].surahNumber);
          },
          child: ColoredBox(
            // color: Colors.transparent,
            color: (surahs.length == 114 && cubit.currentSurahIndex == index)
                ? AppColors.greyYellow
                : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.only(right: 20, left: 20, top: 8),
              child: Row(
                children: [
                  Text(
                    surahs[index].surahNumber.toArabicNums,
                    style: AppStyles.style24u,
                  ),
                  SizedBox(width: 30.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surahs[index].name,
                        style: AppStyles.style22u.copyWith(color: Colors.black),
                      ),
                      Text(
                        surahs[index].place,
                        style: AppStyles.style18u.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: 6.h,
                    children: [
                      Text(
                        'صفحة ${surahs[index].firstPage.toArabicNums}',
                        style: AppStyles.style14u,
                      ),
                      Text(
                        'الجزء ${surahs[index].juzNumber.toArabicNums}',
                        style: AppStyles.style14u.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
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
