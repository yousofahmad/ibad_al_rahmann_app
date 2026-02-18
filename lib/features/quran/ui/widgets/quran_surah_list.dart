import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:quran/surahs_tashkeel.dart';

import 'surah_title_box.dart';

class QuranSurahList extends StatefulWidget {
  const QuranSurahList({super.key});

  @override
  State<QuranSurahList> createState() => _QuranSurahListState();
}

class _QuranSurahListState extends State<QuranSurahList> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with the current surah from the controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<QuranCubit>().surahsController;
      if (controller.hasClients) {
        setState(() {
          _currentPage = controller.page?.round() ?? 0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: context.read<QuranCubit>().surahsController,
      scrollDirection: Axis.horizontal,
      itemCount: 114,
      onPageChanged: (value) {
        setState(() {
          _currentPage = value;
        });
        context.read<QuranCubit>().onSurahListChanged(_currentPage);
      },
      itemBuilder: (context, index) {
        return Row(
          children: [
            SurahTitleBox(
              text: surahArabicTashkel[index],
              selected: index == _currentPage,
            ),
          ],
        );
      },
    );
  }
}
