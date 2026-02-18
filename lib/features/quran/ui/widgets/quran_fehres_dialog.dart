import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/theme/app_colors.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/data/models/searching_surah_model.dart';
import 'package:quran/surah_data.dart';

import 'fehres_items_list_view.dart';

class QuranFehresDialog extends StatelessWidget {
  const QuranFehresDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<List<SearchingSurahModel>> surahsNotifier =
        ValueNotifier<List<SearchingSurahModel>>([]);

    // Initialize surahs list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getSurahs(surahsNotifier);
    });

    void getSurahs({String? value}) {
      _getSurahs(surahsNotifier, value: value);
    }

    return Dialog(
      child: Container(
        width: context.screenWidth * .7,
        height: context.screenHeight * .6,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.white,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              width: double.infinity,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.darkYellow,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Text(
                'فهرس السور',
                style: AppStyles.style16,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
              ),
              child: TextField(
                style: context.bodySmall,
                decoration: InputDecoration(
                  hintText: 'ابحث باسم السورة',
                  hintStyle: context.bodySmall,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  getSurahs(value: value);
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ValueListenableBuilder<List<SearchingSurahModel>>(
                valueListenable: surahsNotifier,
                builder: (context, surahs, child) {
                  return FehresItemsListView(
                    surahs: surahs,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _getSurahs(
    ValueNotifier<List<SearchingSurahModel>> surahsNotifier, {
    String? value,
  }) {
    if (value == null) {
      surahsNotifier.value =
          surah.map((e) => SearchingSurahModel.fromMap(e)).toList();
    } else {
      List surahsData = surah
          .where((e) => (e['arabic'] as String).startsWith(value))
          .toList();
      surahsNotifier.value =
          surahsData.map((e) => SearchingSurahModel.fromMap(e)).toList();
    }
  }
}
