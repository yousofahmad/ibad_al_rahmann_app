import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'tablet_surah_verses_widget.dart';

class TabletMinPageRichText extends StatefulWidget {
  const TabletMinPageRichText({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<TabletMinPageRichText> createState() => _TabletMinPageRichTextState();
}

class _TabletMinPageRichTextState extends State<TabletMinPageRichText> {
  String? currentFontFamilty;
  Future<void> _changeFont() async {
    String family = FontsHelper.getFontFamily(widget.pageNumber);
    await FontsHelper.loadFont(
      family,
      FontsHelper.getFontPath(widget.pageNumber),
    );
    setState(() {
      currentFontFamilty = family;
    });
  }

  void init() async {
    Timer(const Duration(milliseconds: 180), () {
      if (mounted) {
        _changeFont();
      }
    });
  }

  @override
  void initState() {
    init();
    super.initState();
  }

  double getFontSize() {
    final n = widget.pageNumber;
    // if (widget.pageNumber == 50 || widget.pageNumber == 77) {
    //   return 13.6.sp;
    // } else
    if (n == 17) {
      return 11.5.sp;
    } else if (n == 22 ||
        n == 3 ||
        n == 50 ||
        n == 83 ||
        n == 106 ||
        n == 115 ||
        n == 122 ||
        n == 124 ||
        n == 130 ||
        n == 130 ||
        n == 140 ||
        n == 152 ||
        n == 154 ||
        n == 156 ||
        n == 158 ||
        n == 164 ||
        n == 172 ||
        n == 174 ||
        n == 176 ||
        n == 184 ||
        n == 186 ||
        n == 204 ||
        n == 208 ||
        n == 120) {
      return 11.sp;
    } else if (n == 4 || n == 50 || n == 114 || n == 116) {
      return 10.8.sp;
    } else if (n == 000) {
      return 10.8.sp;
    } else {
      return 11.2.sp;
    }
    //! 38, 53, 58, 78, 89
  }

  @override
  Widget build(BuildContext context) {
    if (currentFontFamilty == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      child: Column(
        crossAxisAlignment: widget.pageNumber <= 2
            ? CrossAxisAlignment.center
            : widget.pageNumber.isEven
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: widget.pageNumber == 1 ? 45.w : 30.w,
              ),
              child: BlocBuilder<QuranCubit, QuranState>(
                builder: (context, state) {
                  return TabletSurahVersesWidget(
                    family: currentFontFamilty!,
                    fontSize: getFontSize(),
                    pageNumber: widget.pageNumber,
                    highlightedVerse: state.highligthedVerse,
                  );
                },
              ),
            ),
          ),
          if (widget.pageNumber <= 2)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Text(
                widget.pageNumber.toArabicNums,
                style: context.titleSmall.copyWith(fontSize: 16.sp),
              ),
            ),
        ],
      ),
    );
  }
}
