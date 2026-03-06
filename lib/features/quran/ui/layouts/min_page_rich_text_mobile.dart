import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ibad_al_rahmann/core/helpers/fonts_helper.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../widgets/wbw_page_widget.dart';

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
                right: widget.pageNumber <= 2
                    ? 10.w
                    : (widget.pageNumber.isOdd ? 20.w : 5.w),
                left: widget.pageNumber <= 2
                    ? 10.w
                    : (widget.pageNumber.isEven ? 20.w : 5.w),
              ),
              width: double.infinity, // increase width constraints
              child: WbwPageWidget(pageNumber: widget.pageNumber),
            ),
          ),
        ],
      ),
    );
  }
}
