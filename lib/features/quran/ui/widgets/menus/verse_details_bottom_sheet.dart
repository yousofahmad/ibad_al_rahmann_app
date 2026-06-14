import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ibad_al_rahmann/core/helpers/extensions/app_navigator.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/helpers/tafsir_helper.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/selected_verse_model.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:quran/quran.dart';

class VerseDetailsBottomSheet extends StatelessWidget {
  const VerseDetailsBottomSheet({
    super.key,
    required this.currentVerse,
    this.isDarkOverride,
  });

  final VerseModel currentVerse;
  final bool? isDarkOverride;

  @override
  Widget build(BuildContext context) {
    final translation = getVerseTranslation(
      currentVerse.surahNumber,
      currentVerse.verseNumber,
    );
    final tafsir = TafsirHelper.getVerseTafsir(
      currentVerse.surahNumber,
      currentVerse.verseNumber,
    );

    // Fix 5b: Derive colours from the actual paper colour so custom themes
    // (sepia, dark navy, etc.) are respected rather than the global ThemeMode.
    final paperColor =
        (context.findAncestorWidgetOfExactType<BlocProvider>() != null
            ? context.read<QuranCubit>().state.quranPaperColor
            : null) ??
        (isDarkOverride == true ? Colors.black : Colors.white);
    // Body background follows the Mushaf paper's brightness
    final bool isPaperDark = paperColor.computeLuminance() < 0.5;
    final Color sheetBg = isPaperDark ? const Color(0xFF000000) : Colors.white;
    final Color headerBg = Theme.of(context).primaryColor;
    final Color onSurface = isPaperDark ? Colors.white : Colors.black87;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: sheetBg,
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
              decoration: BoxDecoration(
                color: headerBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: !isPaperDark ? Colors.grey.withAlpha(50) : Colors.white10,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40), // spacer for symmetry
                  Text(
                    'سورة ${getSurahNameArabic(currentVerse.surahNumber)}, الآية: ${currentVerse.verseNumber.toArabicNums}',
                    style: context.headlineLarge.copyWith(color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {
                      context.pop();
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20.sp,
                      color: Colors.white,
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
                    textDirection: TextDirection.rtl,
                    style: context.headlineMedium.copyWith(
                      fontFamily: currentVerse.fontFamily,
                      fontSize: 27.sp,
                      height: 1.2,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Divider(color: onSurface.withAlpha(30)),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'التفسير:',
                      textAlign: TextAlign.right,
                      style: context.headlineMedium.copyWith(color: onSurface),
                    ),
                  ),
                  SelectableText(
                    tafsir,
                    textAlign: TextAlign.right,
                    style: context.headlineMedium.copyWith(color: onSurface),
                  ),
                  SizedBox(height: 30.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الترجمة:',
                        textAlign: TextAlign.right,
                        style: context.headlineMedium.copyWith(color: onSurface),
                      ),
                      Text(
                        'Translation:',
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        style: AppStyles.style18e.copyWith(
                          color: onSurface.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                  SelectableText(
                    translation,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: AppStyles.style18e.copyWith(
                      color: onSurface.withAlpha(180),
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
