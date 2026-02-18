import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/theme/app_assets.dart';
import 'package:ibad_al_rahmann/core/theme/app_styles.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/search/search_cubit.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../bloc/quran/quran_cubit.dart';
import 'verse_searching_bottom_sheet.dart';

class MobileQuranSearch extends StatefulWidget {
  const MobileQuranSearch({super.key});

  @override
  State<MobileQuranSearch> createState() => _MobileQuranSearchState();
}

class _MobileQuranSearchState extends State<MobileQuranSearch> {
  bool isShowed = false;
  PersistentBottomSheetController? _sheetController;
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SearchCubit>();

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: CupertinoSearchTextField(
          placeholder: 'ابحث بالآية',
          controller: cubit.controller,
          padding: const EdgeInsets.all(10),
          style: AppStyles.style16,
          prefixIcon: SvgPicture.asset(AppAssets.svgsSearch),
          suffixMode: OverlayVisibilityMode.editing,
          onSubmitted: (value) {
            isShowed = false;
          },
          onChanged: (value) async {
            if (value.isEmpty) {
              cubit.clear();
              if (_sheetController != null) {
                _sheetController!.close();
                _sheetController = null;
              }
              isShowed = false;
              return;
            }
        
            cubit.onSearch(value);
            if (_sheetController == null) {
              final quranCubit = context.read<QuranCubit>();
        
              isShowed = true;
              _sheetController = showBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return BlocProvider.value(
                    value: quranCubit,
                    child: const VerseSearchingBottomSheet(),
                  );
                },
              );
              _sheetController!.closed.whenComplete(() {
                _sheetController = null;
                isShowed = false;
              });
            }
          },
        ),
      ),
    );
  }
}
