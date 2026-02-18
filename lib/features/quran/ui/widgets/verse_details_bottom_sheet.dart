import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/verse_player/verse_player_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';

class VerseDetailsBottomSheet extends StatelessWidget {
  const VerseDetailsBottomSheet({super.key, required this.currentVerse});

  final VerseModel currentVerse;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VersePlayerCubit>();

    final translation = getVerseTranslation(
      currentVerse.surahNumber,
      currentVerse.verseNumber,
    );
    final tafsir = TafsirHelper.getVerseTafsir(
      currentVerse.surahNumber,
      currentVerse.verseNumber,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.onPrimary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.center,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Visibility(
                    visible: false,
                    child: IconButton(
                      onPressed: null,
                      color: context.primaryColor,
                      icon: const Icon(Icons.settings),
                    ),
                  ),
                  Text(
                    'سورة ${getSurahNameArabic(cubit.currnetVerse?.surahNumber ?? 1)}, الآية: ${cubit.currnetVerse?.verseNumber.toArabicNums ?? 0}',
                    style: context.headlineLarge,
                  ),
                  IconButton(
                    onPressed: () {
                      context.pop();
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20.sp,
                      color: context.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    currentVerse.verse,
                    textAlign: TextAlign.center,
                    style: context.headlineMedium.copyWith(
                      fontFamily: currentVerse.fontFamily,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(color: Colors.grey),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'التفسير:',
                      textAlign: TextAlign.right,
                      style: context.headlineMedium,
                    ),
                  ),
                  SelectableText(
                    tafsir,
                    textAlign: TextAlign.right,
                    style: context.headlineMedium,
                  ),
                  SizedBox(height: 30.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الترجمة:',
                        textAlign: TextAlign.right,
                        style: context.headlineMedium,
                      ),
                      Text(
                        'Translation:',
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: AppStyles.style18e.copyWith(
                          color: context.headlineMedium.color,
                        ),
                      ),
                    ],
                  ),
                  SelectableText(
                    translation,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: AppStyles.style18e.copyWith(
                      color: context.headlineMedium.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
