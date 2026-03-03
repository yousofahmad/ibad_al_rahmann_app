import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/int_extensions.dart';
import 'package:ibad_al_rahmann/core/helpers/extensions/theme.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/helpers/fonts_helper.dart';
import '../widgets/wbw_page_widget.dart';

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

  @override
  Widget build(BuildContext context) {
    if (currentFontFamily == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: EdgeInsets.only(left: 35.w, right: 35.w, top: 10.h, bottom: 4.h),
      child: Column(
        children: [
          Expanded(
            child: Center(child: WbwPageWidget(pageNumber: widget.pageNumber)),
          ),
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
