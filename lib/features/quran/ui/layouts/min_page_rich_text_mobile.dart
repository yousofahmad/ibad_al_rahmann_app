import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';
import 'package:ibad_al_rahmann/features/quran/bloc/quran/quran_cubit.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'mobile_surah_verses_widget.dart';

class MobileMinPageRichText extends StatefulWidget {
  const MobileMinPageRichText({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<MobileMinPageRichText> createState() => _MobileMinPageRichTextState();
}

class _MobileMinPageRichTextState extends State<MobileMinPageRichText> {
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

  double _getFontSize() {
    final n = widget.pageNumber;

    if (n <= 2) {
      return 26.sp;
    } else if (n == 145) {
      return 22.4.sp;
    } else if (n == 532) {
      return 22.5.sp;
    } else if (n == 566 || n == 600 || n == 593) {
      return 22.1.sp;
    } else if (n == 574 || n == 579 || n == 585) {
      return 21.9.sp;
    } else if (n == 577 || n == 578 || n == 583) {
      return 21.35.sp;
    } else if (n == 567 ||
        n == 568 ||
        n == 569 ||
        n == 576 ||
        n == 592 ||
        n == 589 ||
        n == 590) {
      return 21.8.sp;
    } else if (n == 38 ) {
      return 22.5.sp;
    } else if (n == 8 || n == 241) {
      return 22.4.sp;
    } else if (n == 33 || n == 238 || n == 240 || n == 243 || n == 509) {
      return 22.6.sp;
    } else {
      return 22.28.sp;
    }
  }

  // double getFontSize() {
  //   final n = widget.pageNumber;
  //   // if (widget.pageNumber == 50 || widget.pageNumber == 77) {
  //   //   return 13.6.sp;
  //   // } else
  //   if (n == 576) {
  //     return 13.3.sp;
  //   } else if (n == 238 || n == 241 || n == 243 || n == 245 || n == 245) {
  //     return 14.sp;
  //   } else if (n == 579) {
  //     return 13.5.sp;
  //   } else if (n == 578 || n == 577 || n == 585) {
  //     return 13.2.sp;
  //   } else {
  //     return 13.6.sp;
  //   }

  //   //! 38, 53, 58, 78, 89
  // }

  @override
  Widget build(BuildContext context) {
    if (currentFontFamilty == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
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
              padding: EdgeInsets.only(
                top: 8.h,
                bottom: 8.h,
                right: widget.pageNumber.isOdd ? 30.w : 10.w,
                left: widget.pageNumber.isEven ? 30.w : 10.w,
              ),
              width: context.screenWidth * .68,
              child: BlocBuilder<QuranCubit, QuranState>(
                builder: (context, state) {
                  return MobileSurahVersesWidget(
                    family: currentFontFamilty!,
                    fontSize: _getFontSize() * .61,
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
