import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/screen_details.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/helpers/fonts_helper.dart';
import 'tablet_surah_verses_widget.dart';

class TabletFullPageRichText extends StatefulWidget {
  const TabletFullPageRichText({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<TabletFullPageRichText> createState() => _TabletFullPageRichTextState();
}

class _TabletFullPageRichTextState extends State<TabletFullPageRichText> {
  String? currentFontFamily;

  Future<void> _changeFont() async {
    String family = FontsHelper.getFontFamily(widget.pageNumber);
    await FontsHelper.loadFont(
      family,
      FontsHelper.getFontPath(widget.pageNumber),
    );
    setState(() {
      currentFontFamily = family;
    });
  }

  @override
  void initState() {
    _changeFont();
    super.initState();
  }

  double getFontSize() {
    final n = widget.pageNumber;
    if (n <= 2) {
      return 22.sp;
    } else if (n == 145) {
      return 19.4.sp;
    } else if (n == 532) {
      return 19.5.sp;
    } else if (n == 566) {
      return 19.1.sp;
    } else if (n == 574 || n == 579 || n == 585) {
      return 18.9.sp;
    } else if (n == 577 || n == 578 || n == 583) {
      return 18.35.sp;
    } else if (n == 567 || n == 568 || n == 569 || n == 576) {
      return 18.8.sp;
    } else if (n == 8 ||
        n == 15 ||
        n == 17 ||
        n == 32 ||
        n == 33 ||
        n == 38 ||
        n == 82 ||
        n == 83 ||
        n == 99 ||
        n == 102 ||
        n == 104 ||
        n == 78) {
      return 19.6.sp;
    } else {
      return 19.285.sp;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentFontFamily == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 35.w),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: context.isLandscape ? 30.h : 0,
                  ),
                  child: TabletSurahVersesWidget(
                    isFullPage: true,
                    family: currentFontFamily!,
                    fontSize: getFontSize(),
                    pageNumber: widget.pageNumber,
                  ),
                ),
              ),
            ),
          ),
          if (widget.pageNumber <= 2)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Text(
                widget.pageNumber.toArabicNums,
                style: context.titleSmall.copyWith(fontSize: 22.sp),
              ),
            ),
        ],
      ),
    );
  }
}
